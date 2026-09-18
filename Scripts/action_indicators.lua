-- Native widgets subscribe to their action. Never paint over their Icon.
return function(e)
  local originals={}
  local api={}
  function api:Set(widget,action)
    if not e.valid(widget) or not e.valid(action) then return false end
    if e.same(widget.EnhancedInputAction,action) then return true end
    local path=e.path(widget)
    if not originals[path] then
      originals[path]={original=e.path(widget.EnhancedInputAction),assigned=e.path(action)}
    else originals[path].assigned=e.path(action) end
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
    end)
  end
  function api:Forget() originals={} end
  return api
end
