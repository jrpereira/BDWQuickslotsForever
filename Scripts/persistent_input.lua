-- Mod-owned objects have process lifetime. Only subscriptions/active contexts
-- follow the current player. Key changes never replace an InputAction.
return function(e)
  local MODE_TAP_TRIGGER,MODE_HOLD_SUSTAINED=0,2
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
  local function objects(plan)
    if not api.contexts.gameplay then api.contexts.gameplay=e.retain('InputMappingContext','IMC_QuickslotsForever') end
    for _,p in ipairs(plan) do if not api.actions[p.field] then
      local name=p.group and ('IA_'..p.group..'Slot'..p.slot) or ('IA_QuickslotsForever_'..p.field)
      api.actions[p.field]=e.retain('InputAction',name)
    end end
  end
  function api:Owns(context)
    for _,c in pairs(self.contexts) do if e.same(c,context) then return true end end
    return false
  end
  function api:Validate(config)
    local plan={}
    local interaction=config.InteractionMode or 0
    assert(interaction==0 or interaction==1,'Invalid interaction mode')
    local selectiveMode=config.SecondaryWheelMode==MODE_TAP_TRIGGER and MODE_TAP_TRIGGER or MODE_HOLD_SUSTAINED
    assert(interaction==0 or selectiveMode==MODE_TAP_TRIGGER or selectiveMode==MODE_HOLD_SUSTAINED,'Invalid Secondary Wheel mode')
    if interaction==1 and selectiveMode==MODE_HOLD_SUSTAINED then
      local bridge=e.bridge()
      local caps=bridge.GetCapabilities and bridge.GetCapabilities()
      assert(caps and caps.target_delivery_faults==true
        and type(bridge.SetTargetDeliveryFaultHandler)=='function' and type(bridge.IsTargetDeliveryValid)=='function',
        'Selective Hold requires native target delivery fault protection')
    end
    if interaction==0 then
      for _,group in ipairs({'Ability','Consumable'}) do for slot=1,4 do
        local field=group..slot
        local key=config[field]~=0 and assert(e.key(config[field]),'Unsupported key: '..field) or nil
        plan[#plan+1]={field=field,group=group,slot=slot,key=key,mode=config[field..'Mode'] or 0,
          threshold=(config.HoldThresholdMs or 200)/1000}
      end end
    end
    if interaction==1 then
      local mode=selectiveMode
      local secondary=config.SecondaryWheelKey or 164
      plan[#plan+1]={field='SecondaryWheelKey',key=secondary~=0 and assert(e.key(secondary),'Unsupported Secondary Wheel key') or nil,
        mode=mode,threshold=(config.HoldThresholdMs or 200)/1000}
      if mode==MODE_TAP_TRIGGER then
        local primary=config.PrimaryWheelKey or 0
        local primaryKey=primary~=0 and assert(e.key(primary),'Unsupported Primary Wheel key') or nil
        assert(not primaryKey or not plan[#plan].key or primaryKey~=plan[#plan].key,'Wheel selection keys must differ')
        plan[#plan+1]={field='PrimaryWheelKey',key=primaryKey,mode=MODE_TAP_TRIGGER,threshold=(config.HoldThresholdMs or 200)/1000}
      end
    end
    return plan
  end
  function api:Configure(config)
    local plan=self:Validate(config)
    objects(plan)
    self.interaction=config.InteractionMode or 0
    self.secondaryWheelMode=config.SecondaryWheelMode==MODE_TAP_TRIGGER and MODE_TAP_TRIGGER or MODE_HOLD_SUSTAINED
    local context=self.contexts.gameplay
    -- This is our private context, never a native/game context.
    context:UnmapAll()
    for _,p in ipairs(plan) do
      local a=assert(self.actions[p.field],'Persistent action missing')
      a.ValueType=0;a.bConsumeInput=false;a.bTriggerWhenPaused=false
      e.trigger(a,p.mode,p.threshold)
      if p.key then context:MapKey(a,{KeyName=e.name(p.key)}) end
    end
    e.each(context.Mappings,function(_,m) m.SettingBehavior=2 end)
  end
  function api:Close()
    if self.target then
      local ok,err=e.bridge().CloseInputComponent(self.target)
      if not ok then return false,err end
      self.target=nil
      self.deliveryGuard=false
    end
    if e.valid(self.sub) and self.contexts.gameplay then self.sub:RemoveMappingContext(self.contexts.gameplay,options) end
    self.sub=nil
    return true
  end
  function api:IsDeliveryValid(target)
    if target~=self.target then return false end
    if not self.deliveryGuard then return not (self.interaction==1 and self.secondaryWheelMode==MODE_HOLD_SUSTAINED) end
    local ok,healthy=pcall(e.bridge().IsTargetDeliveryValid,target)
    return ok and healthy==true
  end
  function api:Bind(input,sub,defs,callback)
    local bridge=e.bridge()
    local target,err=bridge.OpenInputComponent(e.path(input))
    if not target then return false,err end
    self.target=target;self.sub=sub
    self.deliveryGuard=false
    local caps=bridge.GetCapabilities and bridge.GetCapabilities()
    if caps and caps.target_delivery_faults==true then
      local guarded,why=bridge.SetTargetDeliveryFaultHandler(target,function(event)
        if self.target==target and e.delivery_fault then e.delivery_fault(target,event.reason) end
      end)
      if not guarded then self:Close();return false,why end
      self.deliveryGuard=true
    elseif self.interaction==1 and self.secondaryWheelMode==MODE_HOLD_SUSTAINED then
      self:Close();return false,'Native target delivery fault protection is required'
    end
    for _,entry in ipairs(defs) do
      local action=assert(self.actions[entry.field],'Persistent action missing')
      e.initialize_identity(action)
      local phases=entry.momentary and {'Started','Completed','Canceled'} or {'Triggered'}
      for _,phase in ipairs(phases) do
        local handle,why=bridge.BindAction(target,e.path(action),phase,callback(entry,phase))
        if not handle then self:Close();return false,why end
      end
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
