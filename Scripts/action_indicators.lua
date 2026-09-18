-- Native widgets subscribe to their action. Never paint over their Icon.
return function(e)
  local originals={}
  local api={}
  for line in ((e.load and e.load()) or ''):gmatch('[^\n]+') do
    local path,original,assigned=line:match('^([^\t]+)\t([^\t]*)\t([^\t]+)$')
    if path then originals[path]={original=original~='' and original or nil,assigned=assigned} end
  end
  local function save()
    if not e.save then return end
    local lines={}
    for p,r in pairs(originals) do lines[#lines+1]=p..'\t'..(r.original or '')..'\t'..r.assigned end
    table.sort(lines);e.save(table.concat(lines,'\n'))
  end
  local function prune()
    local changed=false
    for path in pairs(originals) do
      if not e.valid(e.resolve(path)) then originals[path]=nil;changed=true end
    end
    return changed
  end
  function api:Set(widget,action)
    if not e.valid(widget) or not e.valid(action) then return false end
    if e.same(widget.EnhancedInputAction,action) then return true end
    -- Setup-only pruning bounds the scalar journal as native HUDs are replaced.
    prune()
    local path=e.path(widget)
    if not originals[path] then
      originals[path]={original=e.path(widget.EnhancedInputAction),assigned=e.path(action)}
    else originals[path].assigned=e.path(action) end
    save()
    widget:SetEnhancedInputAction(action)
    return true
  end
  function api:RestoreAll()
    return pcall(function()
      for path,r in pairs(originals) do
        local w=e.resolve(path)
        if e.valid(w) and e.path(w.EnhancedInputAction)==r.assigned then
          w:SetEnhancedInputAction(r.original and e.resolve(r.original) or nil)
        end
        originals[path]=nil
      end
      save()
    end)
  end
  function api:Forget() originals={};save() end
  function api:Prune()
    if prune() then save() end
  end
  return api
end
