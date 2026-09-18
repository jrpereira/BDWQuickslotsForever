-- Mod-owned objects have process lifetime. Only subscriptions/active contexts
-- follow the current player. Key changes never replace an InputAction.
return function(e)
  local api={actions={},contexts={},target=nil,sub=nil,inventorySub=nil}
  local options={bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=false,bNotifyUserSettings=false}
  local journal=e.load_inventory and e.load_inventory()
  if journal and journal~='' then
    local overlay,priority,sub,context=journal:match('^([^\t]+)\t([%-0-9]+)\t([^\t]+)\t([^\t]+)$')
    if overlay then
      api.overlayPath=overlay;api.overlayPriority=tonumber(priority)
      api.inventorySub=e.resolve(sub)
      local c=e.resolve(context);if e.valid(c) then api.contexts.inventory=c end
    end
  end
  local function objects()
    if not api.contexts.gameplay then api.contexts.gameplay=e.retain('InputMappingContext','IMC_QuickslotsForever') end
    for _,group in ipairs({'Ability','Consumable'}) do for slot=1,4 do
      local field=group..slot
      if not api.actions[field] then api.actions[field]=e.retain('InputAction','IA_'..group..'Slot'..slot) end
    end end
  end
  function api:Owns(context)
    for _,c in pairs(self.contexts) do if e.same(c,context) then return true end end
    return false
  end
  function api:Configure(config)
    objects()
    local plan={}
    for _,group in ipairs({'Ability','Consumable'}) do for slot=1,4 do
      local field=group..slot
      plan[#plan+1]={field=field,key=assert(e.key(config[field]),'Unsupported key: '..field),mode=config[field..'Mode'] or 0}
    end end
    local context=self.contexts.gameplay
    -- This is our private context, never a native/game context.
    context:UnmapAll()
    for _,p in ipairs(plan) do
      local a=self.actions[p.field]
      a.ValueType=0;a.bConsumeInput=false;a.bTriggerWhenPaused=false
      e.trigger(a,p.mode,config.HoldThresholdMs/1000)
      context:MapKey(a,{KeyName=e.name(p.key)})
    end
    e.each(context.Mappings,function(_,m) m.SettingBehavior=2 end)
  end
  function api:Close()
    if self.target then
      local ok,err=e.bridge().CloseInputComponent(self.target)
      if not ok then return false,err end
      self.target=nil
    end
    if e.valid(self.sub) and self.contexts.gameplay then self.sub:RemoveMappingContext(self.contexts.gameplay,options) end
    self.sub=nil
    return true
  end
  function api:Bind(input,sub,defs,callback)
    local bridge=e.bridge()
    local target,err=bridge.OpenInputComponent(e.path(input))
    if not target then return false,err end
    self.target=target;self.sub=sub
    for _,entry in ipairs(defs) do
      local action=assert(self.actions[entry.field],'Persistent action missing')
      e.initialize_identity(action)
      local handle,why=bridge.BindAction(target,e.path(action),'Triggered',callback(entry))
      if not handle then self:Close();return false,why end
    end
    sub:AddMappingContext(self.contexts.gameplay,10000,options)
    return true
  end
  function api:EnsureGameplay(sub)
    if not e.present(self.contexts.gameplay) then sub:AddMappingContext(self.contexts.gameplay,10000,options) end
  end
  function api:PrepareInventory()
    if self.inventoryReady then return true end
    local actions={}
    for slot,direction in ipairs({'Left','Top','Right','Bottom'}) do
      actions[slot]=e.native_action(direction)
      if not e.valid(actions[slot]) then return false end
    end
    local c=self.contexts.inventory or e.retain('InputMappingContext','IMC_QuickslotsForever_Inventory')
    self.contexts.inventory=c
    c:UnmapAll()
    local numbers={'One','Two','Three','Four'}
    local directions={'Left','Up','Right','Down'}
    for slot,a in ipairs(actions) do
      for _,key in ipairs({numbers[slot],directions[slot],'Gamepad_DPad_'..directions[slot]}) do
        c:MapKey(a,{KeyName=e.name(key)})
      end
    end
    e.each(c.Mappings,function(_,m) m.SettingBehavior=2 end)
    self.inventoryReady=true
    return true
  end
  function api:AttachInventory(overlay,sub)
    if not self:PrepareInventory() then return false end
    local context=self.contexts.inventory
    if e.valid(overlay.InputMapping) and not e.same(overlay.InputMapping,context) then
      error('Inventory overlay already owns a different mapping context')
    end
    if self.inventorySub and not e.same(self.inventorySub,sub) then self:CloseInventory() end
    if self.overlayPath and self.overlayPath~=e.path(overlay) then self:CloseInventory() end
    if not self.overlayPath then
      self.overlayPath=e.path(overlay)
      self.overlayPriority=overlay.InputMappingPriority
    end
    if e.same(overlay.InputMapping,context) and overlay.InputMappingPriority==10002
        and e.same(self.inventorySub,sub) then return true end
    if e.save_inventory then
      e.save_inventory(table.concat({self.overlayPath,self.overlayPriority,e.path(sub),e.path(context)},'\t'))
    end
    -- CommonUI also removes this context on native deactivation/destruction.
    overlay.InputMapping=context;overlay.InputMappingPriority=10002
    self.inventorySub=sub
    return true
  end
  function api:OpenInventory(overlay,sub)
    if not self:AttachInventory(overlay,sub) then return false end
    local context=self.contexts.inventory
    if not e.present(context) then
      sub:AddMappingContext(context,10002,{bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false})
    end
    return true
  end
  function api:DeactivateInventory()
    if e.valid(self.inventorySub) and self.contexts.inventory
        and (not e.present or e.present(self.contexts.inventory)) then
      self.inventorySub:RemoveMappingContext(self.contexts.inventory,options)
    end
    -- Leave InputMapping attached: CommonUI must activate it on the next S open
    -- even when native C++ bypasses the reflected ActivateWidget hook.
  end
  function api:CloseInventory()
    self:DeactivateInventory()
    self.inventorySub=nil
    local overlay=self.overlayPath and e.resolve(self.overlayPath)
    if e.valid(overlay) and e.same(overlay.InputMapping,self.contexts.inventory) then
      overlay.InputMapping=nil
      overlay.InputMappingPriority=self.overlayPriority
    end
    self.overlayPath=nil;self.overlayPriority=nil
    if e.save_inventory then e.save_inventory('') end
  end
  return api
end
