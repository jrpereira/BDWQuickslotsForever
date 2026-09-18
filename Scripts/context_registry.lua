-- Shared UObject values are unsafe after GC: UE4SS constructs their Lua wrapper
-- before Lua can call IsValid. Share paths only, and resolve against live objects.
return function(env)
  local key="QuickslotsForever.DrawContextPath.v1"
  local api={}
  function api:ForgetLegacy()
    -- Never read these legacy entries, including during an upgrade/hot reload.
    env.set_shared("QuickslotsForever.EnhancedContext",nil)
    env.set_shared("QuickslotsForever.DrawContext",nil)
  end
  function api:Remember(context,subsystem)
    local contextPath,ownerPath=env.path(context),env.path(subsystem)
    assert(type(contextPath)=="string" and type(ownerPath)=="string"
      and contextPath:sub(1,#ownerPath+1)==ownerPath..".","Draw context must belong to the active subsystem")
    env.set_shared(key,contextPath)
  end
  function api:Clear(subsystem)
    local path=env.get_shared(key)
    if path==nil then return true end
    assert(type(path)=="string","Draw context registry must contain a path string")
    local ownerPath=env.path(subsystem)
    if type(ownerPath)~="string" then return false,"live subsystem unavailable" end
    -- A replacement subsystem owns a different lifetime; do not resolve or
    -- touch an old context in the previous world just to clean its bookkeeping.
    if path:sub(1,#ownerPath+1)==ownerPath.."." then
      local context=env.resolve(path)
      if env.valid(context) then env.remove(subsystem,context) end
    end
    env.set_shared(key,nil)
    return true
  end
  return api
end
