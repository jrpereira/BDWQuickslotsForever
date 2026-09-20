-- Event-only wheel selection. Native Quickslot actions own slot activation in
-- Selective mode; Direct actions dispatch directly.
return function()
  local MODE_HOLD_SUSTAINED=2
  local api={mode=0,primary='Consumable',active='Consumable'}
  function api:Configure(config)
    self.mode=config.InteractionMode or 0
    assert(self.mode==0 or self.mode==1,'Invalid interaction mode')
    self.primary=config.PrimaryWheel==1 and 'Ability' or 'Consumable'
    self:Reset()
  end
  function api:Reset()
    self.active=self.primary
  end
  function api:Select(group)
    if self.active==group then return false end
    self.active=group
    return true
  end
  function api:Phase(binding,phase)
    -- Hold Sustained is a state, unlike Hold Trigger (1), which is a single
    -- threshold-triggered action handled by Enhanced Input.
    if binding.mode==MODE_HOLD_SUSTAINED or binding.momentary then
      if phase=='Started' then return false,self:Select(self.primary=='Ability' and 'Consumable' or 'Ability') end
      if phase=='Completed' or phase=='Canceled' then return false,self:Select(self.primary) end
      return false
    end
    if binding.select then
      if phase=='Triggered' then return false,self:Select(binding.select=='primary' and self.primary or (self.primary=='Ability' and 'Consumable' or 'Ability')) end
      return false
    end
    return self.mode==0 and phase=='Triggered'
  end
  return api
end
