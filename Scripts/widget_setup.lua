-- A delayed job belongs to one context. Only missing children request another.
return function(e)
  local pending={}
  local completed={}
  local epoch=0
  local api={}
  function api:Invalidate() epoch=epoch+1;pending={};completed={} end
  function api:Request(context,kind)
    if not e.valid(context) or not e.enabled() then return end
    local key=e.key(context,kind)
    if not key then return end
    local previous=pending[key]
    if previous and e.valid(previous.context) then return end
    local done=completed[key]
    if done and e.valid(done.context) then
      local signature=e.signature and e.signature(context,kind)
      if not e.signature or (e.same_signature and e.same_signature(done.signature,signature))
          or (not e.same_signature and done.signature==signature) then return end
    end
    local ticket={epoch=epoch,context=context}
    pending[key]=ticket
    local function current()
      return ticket.epoch==epoch and pending[key]==ticket
    end
    local function stop() if current() then pending[key]=nil end end
    local function alive()
      if not current() then return false end
      if not e.enabled() or not e.valid(context) then stop();return false end
      return true
    end
    local schedule
    schedule=function()
      if not alive() then return end
      local ok,err=pcall(e.delay,100,function()
        if not current() then return end
        local queued,why=pcall(e.queue,function()
          if not alive() then return end
          local success,result=pcall(e.run,context,kind)
          if not success then stop();e.log('Wheel setup failed: '..tostring(result));return end
          if result=='children_missing' then schedule()
          else
            if result==true and e.remember_success~=false and alive() then
              completed[key]={context=context,signature=e.signature and e.signature(context,kind)}
            end
            stop()
          end
        end)
        if not queued then stop();e.log('Wheel setup dispatch failed: '..tostring(why)) end
      end)
      if not ok then stop();e.log('Wheel setup delay failed: '..tostring(err)) end
    end
    schedule()
  end
  return api
end
