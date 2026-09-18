-- Event-requested recovery only. Idle ticks neither queue work nor inspect Unreal.
return function(env)
  local lanes={}
  local pending=false
  local running=false
  local epoch=0
  local api={}
  function api:Request(name)
    -- Native mapping calls made by our own repair must not perpetuate repair.
    if running then return end
    lanes[name]=env.attempts or 6
  end
  -- Explicit dependency completion may enqueue another lane while work runs.
  -- Reflected mapping callbacks still use Request and cannot create a self-loop.
  function api:AfterReady(name)
    lanes[name]=env.attempts or 6
  end
  function api:Invalidate()
    epoch=epoch+1
    lanes={}
  end
  function api:Tick()
    if not env.enabled() then return true end
    if pending or next(lanes)==nil then return false end
    pending=true
    local queuedEpoch=epoch
    local ok,err=pcall(env.queue,function()
      if queuedEpoch~=epoch or not env.enabled() then pending=false; return end
      local batch=lanes
      lanes={}
      running=true
      for _,name in ipairs({'input','inventory','hud','cleanup'}) do
        local remaining=batch[name]
        if remaining then
          local success,done=pcall(env.run,name)
          if not success or done~=true then
            if remaining>1 then lanes[name]=math.max(lanes[name] or 0,remaining-1)
            else env.log(name..' recovery exhausted; waiting for next lifecycle event: '..tostring(done)) end
          end
        end
      end
      running=false
      pending=false
    end)
    if not ok then
      pending=false
      -- Dispatch failure also consumes a bounded attempt.
      for name,n in pairs(lanes) do lanes[name]=n>1 and n-1 or nil end
      env.log('Recovery dispatch failed: '..tostring(err))
    end
    return false
  end
  return api
end
