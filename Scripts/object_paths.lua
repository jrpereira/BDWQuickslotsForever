-- Discovery cache stores strings only. Resolve each object fresh on the game thread.
-- Creation notifications invalidate discovery; two refresh passes cover deferred
-- construction. Every ten visits also rediscover to recover missed notifications.
-- If notifications cannot be installed, retain original scan behavior.
return function(env,class)
  local paths={}
  local revision=0
  local settledRevision=-1
  local settlePasses=2
  local notifications=false
  local passes=0
  local api={}
  function api:EnableNotifications() notifications=true end
  function api:Invalidate() revision=revision+1; settlePasses=2 end
  function api:Visit(fn)
    passes=passes+1
    if not notifications or settledRevision~=revision or settlePasses>0 or passes>=10 then
      local startedRevision=revision
      local ok,objects=pcall(env.find,class)
      if not ok then return false end
      local nextPaths={}
      for _,o in ipairs(objects or {}) do
        if env.valid(o) and (not env.live or env.live(o)) then
          local path=env.path(o)
          if type(path)=='string' and not path:find('Default__',1,true) then nextPaths[path]=true end
        end
      end
      paths=nextPaths
      passes=0
      if revision==startedRevision then settledRevision=revision; settlePasses=math.max(0,settlePasses-1) end
    end
    for path in pairs(paths) do
      local o=env.resolve(path)
      if env.valid(o) then fn(o) else paths[path]=nil end
    end
    return true
  end
  return api
end
