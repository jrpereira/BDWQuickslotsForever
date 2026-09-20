-- Action-level native input gates. Native mappings and saved keys are never changed.
return function(e)
  local marker=e.marker or 'QSF_NativeActionGate'
  local pending={}
  local first=true
  local api={}

  local function trigger_list(action)
    local list={}
    e.each(action.Triggers,function(_,trigger)
      trigger=e.unwrap and e.unwrap(trigger) or trigger
      if e.valid(trigger) then list[#list+1]=trigger end
    end)
    return list
  end

  local function owned(trigger,action)
    if not e.valid(trigger) or not e.valid(action) then return false end
    return e.path(trigger)==e.path(action)..':'..marker
  end

  local function has_owned(action)
    for _,trigger in ipairs(trigger_list(action)) do if owned(trigger,action) then return true end end
    return false
  end

  local function flush()
    local changed={}
    for path,action in pairs(pending) do
      if e.valid(action) then changed[#changed+1]=action else pending[path]=nil end
    end
    if #changed>0 then
      assert(e.rebuild(changed)~=false,'Native action gate rebuild rejected')
      for _,action in ipairs(changed) do pending[e.path(action)]=nil end
    end
    first=false
    return #changed
  end

  local function update_action(action,wanted,dummy)
    local before=trigger_list(action)
    local after={}
    local gate
    local changed=false
    for _,trigger in ipairs(before) do
      if owned(trigger,action) then
        if wanted and not gate then
          gate=trigger
          after[#after+1]=trigger
        else
          changed=true -- remove stale duplicate or a no-longer-wanted gate
        end
      else
        after[#after+1]=trigger
      end
    end
    if wanted and not gate then
      gate=e.construct(action,marker)
      assert(e.valid(gate),'Native action gate construction failed for '..e.path(action))
      after[#after+1]=gate
      changed=true
    end
    if gate then
      local current=e.chord(gate)
      if not e.same(current,dummy) then e.set_chord(gate,dummy);changed=true end
    end
    if changed then e.set_triggers(action,after) end
    return changed
  end

  function api:Update()
    local actions=e.actions()
    local needsDummy=false
    for _,action in ipairs(actions) do
      if e.valid(action) and e.target(action) then needsDummy=true;break end
    end
    local dummy=needsDummy and e.retain_dummy() or nil
    if needsDummy then assert(e.valid(dummy),'Persistent native-action gate is unavailable') end
    local changed={}
    for _,action in ipairs(actions) do
      if e.valid(action) then
        local wanted=e.target(action)
        local altered=update_action(action,wanted,dummy)
        if altered then changed[#changed+1]=action end
        if altered or (first and (wanted or has_owned(action))) then pending[e.path(action)]=action end
      end
    end
    flush()
    return true,#changed
  end

  function api:RestoreAll()
    local changed={}
    for _,action in ipairs(e.actions()) do
      if e.valid(action) then
        local hadGate=has_owned(action)
        if update_action(action,false,nil) then changed[#changed+1]=action end
        if hadGate then pending[e.path(action)]=action end
      end
    end
    flush()
    return true,#changed
  end

  return api
end
