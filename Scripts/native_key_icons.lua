-- Display-only adapter. Retain scalar state/path strings, never brush/UObject wrappers.
return function(env)
  local records={}
  local api={}
  local function restore(widget,record)
    widget:SetHoldDisplayOverride(record.held)
    widget:UpdateActionWidget()
    widget:InvalidateLayoutAndVolatility()
  end
  function api:Set(widget,vk,hold,context)
    if not env.valid(widget) or not context then return false end
    if not context.keyboard then
      local path=env.path(widget)
      if path and records[path] then
        local ok,err=pcall(restore,widget,records[path])
        if not ok then env.log('Native input-method restoration failed: '..tostring(err)); return false end
        records[path]=nil
      end
      return false
    end
    local key=env.key(vk)
    if not key then return false end
    local ok,result=pcall(function()
      if not env.has_brush(context.system,key) then return false end
      local brush=env.brush(context.system,key)
      if brush==nil then return false end
      local path=env.path(widget)
      if not path then return false end
      local record=records[path]
      if not record then
        record={held=widget:IsHeldAction()}
        records[path]=record
      end
      -- Hold override refreshes native state; apply the desired brush afterwards.
      -- No input action, input binding or mapping is changed.
      widget:SetHoldDisplayOverride(hold==1)
      widget.Icon=brush
      widget:InvalidateLayoutAndVolatility()
      return true
    end)
    if not ok then env.log('Native key display update failed: '..tostring(result)); return false end
    return result==true
  end
  function api:RestoreAll()
    for path,record in pairs(records) do
      local ok,err=pcall(function()
        local widget=env.resolve(path)
        if env.valid(widget) then
          -- Regenerate the native brush from the untouched native action binding.
          restore(widget,record)
        end
      end)
      if not ok then return false,tostring(err) end
      records[path]=nil
    end
    return true
  end
  function api:Forget() records={} end
  return api
end
