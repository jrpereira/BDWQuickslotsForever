-- Fresh lifecycle work never waits behind another task's readiness retry.
return function(env)
  local ready,waiting={},{}
  local pending,timer,running
  local epoch=0
  local api={}
  local dispatch,schedule_retry
  local function failed(name,left,why)
    if left>1 then waiting[name]=math.max(waiting[name] or 0,left-1)
    else env.log(name..' recovery exhausted; waiting for next lifecycle event: '..tostring(why)) end
  end
  function api:Request(name)
    if running or not env.enabled() or waiting[name] then return end
    ready[name]=ready[name] or env.attempts or 6
    dispatch()
  end
  function api:AfterReady(name)
    waiting[name]=nil
    ready[name]=ready[name] or env.attempts or 6
    dispatch()
  end
  function api:Invalidate()
    epoch=epoch+1;ready={};waiting={};pending=nil;timer=nil
  end
  schedule_retry=function()
    if timer or next(waiting)==nil or not env.enabled() then return end
    local ticket={epoch=epoch};timer=ticket
    local ok,err=pcall(env.delay,env.retry_ms or 500,function()
      if timer~=ticket or epoch~=ticket.epoch then return end
      timer=nil
      for name,left in pairs(waiting) do ready[name]=ready[name] or left end
      waiting={};dispatch()
    end)
    if not ok and timer==ticket then
      timer=nil;waiting={}
      env.log('Recovery retry scheduling failed; waiting for next lifecycle event: '..tostring(err))
    end
  end
  dispatch=function()
    if pending or running or next(ready)==nil or not env.enabled() then return end
    local ticket={epoch=epoch};pending=ticket
    local ok,err=pcall(env.queue,function()
      if pending~=ticket or epoch~=ticket.epoch then return end
      pending=nil
      if not env.enabled() then ready={};waiting={};return end
      running=true
      for _,name in ipairs({'input','inventory','hud','cleanup'}) do
        if epoch~=ticket.epoch then break end
        local left=ready[name];ready[name]=nil
        if left then
          local success,done=pcall(env.run,name)
          if epoch==ticket.epoch and (not success or done~=true) then failed(name,left,done) end
        end
      end
      running=false
      dispatch();schedule_retry()
    end)
    if not ok and pending==ticket and epoch==ticket.epoch then
      pending=nil
      local batch=ready;ready={}
      for name,left in pairs(batch) do failed(name,left,err) end
      env.log('Recovery dispatch failed: '..tostring(err));schedule_retry()
    end
  end
  return api
end
