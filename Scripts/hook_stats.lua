-- Count only on the hot path. Wall-clock reads and formatting are on demand.
return function(now)
  local started=now()
  local rows={}
  local api={}
  function api:Wrap(name,fn)
    if not fn then return nil end
    local row={name=name,count=0}
    rows[#rows+1]=row
    return function(...)
      row.count=row.count+1
      return fn(...)
    end
  end
  function api:Reset()
    started=now()
    for _,row in ipairs(rows) do row.count=0 end
  end
  function api:Report(emit)
    local elapsed=math.max(0,now()-started)
    emit('Hook counters: '..elapsed..' wall-clock seconds since reset (1-second resolution).')
    for _,row in ipairs(rows) do
      emit(string.format('%s: %d calls; %s calls/s',row.name,row.count,
        elapsed>0 and string.format('%.3f',row.count/elapsed) or 'n/a'))
    end
  end
  return api
end
