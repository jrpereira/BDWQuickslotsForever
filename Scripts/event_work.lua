-- Hooks schedule work directly. Only failed readiness attempts schedule a
-- bounded one-shot retry; idle means no scheduled callback at all.
return function(env)
  local lanes={}
  local pending
  local running=false
  local epoch=0
  local api={}
  local schedule
  local followup=false
  function api:Request(name)
    -- Native mapping calls made by our own repair must not perpetuate repair.
    if running then return end
    if not env.enabled() then return end
    lanes[name]=env.attempts or 6
    schedule(false)
  end
  -- Explicit dependency completion may enqueue another lane while work runs.
  -- Reflected mapping callbacks still use Request and cannot create a self-loop.
  function api:AfterReady(name)
    lanes[name]=env.attempts or 6
    followup=true
    schedule(false)
  end
  function api:Invalidate()
    epoch=epoch+1
    lanes={}
    pending=nil
    followup=false
  end
  schedule=function(retry)
    if pending or running or next(lanes)==nil or not env.enabled() then return end
    local ticket={}
    pending=ticket
    local queuedEpoch=epoch
    local function dispatch()
      if queuedEpoch~=epoch or pending~=ticket then return end
      if not env.enabled() then pending=nil;lanes={};return end
      local ok,err=pcall(env.queue,function()
      if queuedEpoch~=epoch or pending~=ticket then return end
      pending=nil
      if not env.enabled() then lanes={};return end
      local batch=lanes
      lanes={}
      running=true
      followup=false
      for _,name in ipairs({'input','inventory','hud','cleanup'}) do
        if queuedEpoch~=epoch then break end
        local remaining=batch[name]
        if remaining then
          local success,done=pcall(env.run,name)
          if queuedEpoch==epoch and (not success or done~=true) then
            if remaining>1 then lanes[name]=math.max(lanes[name] or 0,remaining-1)
            else env.log(name..' recovery exhausted; waiting for next lifecycle event: '..tostring(done)) end
          end
        end
      end
      running=false
      schedule(not followup)
    end)
    if not ok then
      if pending~=ticket or queuedEpoch~=epoch then return end
      pending=nil
      -- Dispatch failure also consumes a bounded attempt.
      for name,n in pairs(lanes) do lanes[name]=n>1 and n-1 or nil end
      env.log('Recovery dispatch failed: '..tostring(err))
      schedule(true)
    end
    end
    if retry then
      local ok,err=pcall(env.delay,env.retry_ms or 500,dispatch)
      if not ok and pending==ticket then
        pending=nil;lanes={}
        env.log('Recovery retry scheduling failed; waiting for next lifecycle event: '..tostring(err))
      end
    else dispatch() end
  end
  return api
end
