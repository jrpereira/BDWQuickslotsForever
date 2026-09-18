-- DMM owns Apply/external-edit handling. No timers or filesystem monitoring here.
return function(e)
  local pending=false
  return e.subscribe('QuickslotsForever',function()
    if pending then return end
    pending=true
    local ok,err=pcall(e.queue,function()
      pending=false
      local applied,why=pcall(function()
        local text=assert(e.read(),'Committed configuration unavailable')
        assert(text:match('%[General%]') and text:match('%[Bindings%]'),'Incomplete committed configuration')
        if text~=e.current() then assert(e.apply(text)~=false,'Configuration could not be applied') end
      end)
      if not applied then e.log('Configuration Apply failed: '..tostring(why)) end
    end)
    if not ok then pending=false;e.log('Configuration dispatch failed: '..tostring(err)) end
  end)
end
