-- Event-driven Controls presentation. Identity resolution belongs to the adapter.
-- Retain paths and scalar flags only; never retain Unreal wrappers across events.
return function(env)
  local owned={}
  local api={}
  local function restore(path,record)
    local row=env.resolve(path)
    -- The same widget may have been rebound to another action. Undo our old
    -- presentation before allowing it to represent that new action.
    if env.valid(row) and env.instance(row)==record.instance then
      env.opacity(row,record.opacity)
      env.enabled(row,record.enabled)
    end
    owned[path]=nil
  end
  function api:Restore()
    for path,record in pairs(owned) do restore(path,record) end
  end
  function api:Forget() owned={} end
  function api:Update(panel)
    if not env.active() then self:Restore(); return 0 end
    if not env.valid(panel) or env.tag(panel)~='UI.Settings.Controls' then return 0 end
    local seen={}
    local count=0
    env.rows(panel,function(row)
      if not env.valid(row) then return end
      local identity=env.identity(row)
      local path=env.path(row)
      if not path or not identity or not env.target(identity) then return end
      local instance=env.instance(row)
      if instance==nil then return end
      local record=owned[path]
      if record and (record.identity~=identity or record.instance~=instance) then
        restore(path,record)
        record=nil
      end
      if not record then
        local opacity,enabled=env.state(row)
        if type(opacity)~='number' or opacity~=opacity or opacity<0 or opacity>1
            or type(enabled)~='boolean' then return end
        record={identity=identity,instance=instance,opacity=opacity,enabled=enabled}
        owned[path]=record
      end
      seen[path]=true
      env.enabled(row,false)
      env.opacity(row,record.opacity*0.4)
      count=count+1
    end)
    for path,record in pairs(owned) do
      if not seen[path] then restore(path,record) end
    end
    return count
  end
  return api
end
