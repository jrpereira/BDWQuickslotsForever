-- Discovery cache stores strings only. Resolve each object fresh on the game thread.
-- Discover once, then invalidate only at an explicit lifecycle boundary.
-- Creation callbacks add known live objects directly; no periodic rescans.
return function(env,class)
  local paths={}
  local revision=0
  local settledRevision=-1
  local api={}
  function api:EnableNotifications() end -- compatibility with creation registration
  function api:Invalidate() revision=revision+1 end
  function api:Add(o)
    if env.valid(o) and (not env.live or env.live(o)) then
      local p=env.path(o)
      if type(p)=='string' and not p:find('Default__',1,true) then paths[p]=true end
    end
  end
  function api:Visit(fn)
    if settledRevision~=revision then
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
      if revision==startedRevision then settledRevision=revision end
    end
    for path in pairs(paths) do
      local o=env.resolve(path)
      if env.valid(o) then fn(o) else paths[path]=nil end
    end
    return true
  end
  return api
end
