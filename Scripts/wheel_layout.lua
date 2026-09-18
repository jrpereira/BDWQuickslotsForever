-- Own only the reversible dual-wheel layout. Input bindings are independent.
return function(env)
  local record
  local prompts={}
  local api={}
  local function number(o,k)
    return assert(tonumber(env.unwrap(env.safe(o,k))),"unavailable layout property: "..k)
  end
  local function translation(w)
    local t=env.safe(env.safe(w,"RenderTransform"),"Translation")
    return {X=number(t,"X"),Y=number(t,"Y")}
  end
  local function set_translation(w,x,y)
    local current=translation(w)
    if current.X~=x or current.Y~=y then w:SetRenderTranslation({X=x,Y=y}) end
  end
  local function slot_state(w)
    local slot=env.safe(w,"Slot")
    local p=env.safe(slot,"Padding")
    return {padding={Left=number(p,"Left"),Top=number(p,"Top"),Right=number(p,"Right"),Bottom=number(p,"Bottom")},
      horizontal=number(slot,"HorizontalAlignment"),vertical=number(slot,"VerticalAlignment")}
  end
  local function restore_slot(w,state)
    local slot=env.safe(w,"Slot")
    assert(env.valid(slot),"restored switcher slot unavailable")
    slot:SetPadding(state.padding)
    slot:SetHorizontalAlignment(state.horizontal)
    slot:SetVerticalAlignment(state.vertical)
  end
  local function restore_layout()
    local r=record
    if not r then return end
    if not env.valid(r.hud) or not env.valid(r.switcher) or not env.valid(r.ability) or not env.valid(r.consumable) then
      record=nil -- Reconstructed HUDs receive a fresh native snapshot.
      return
    end
    -- Do not remove unexpected children introduced by another owner.
    for i=0,r.switcher:GetChildrenCount()-1 do
      local child=r.switcher:GetChildAt(i)
      assert(env.same(child,r.ability) or env.same(child,r.consumable),"switcher children changed externally")
    end
    for _,child in ipairs(r.order) do
      local owner=env.parent(child)
      if env.valid(owner) then assert(owner:RemoveChild(child)~=false,"could not detach wheel for restoration") end
    end
    for i,child in ipairs(r.order) do
      assert(env.valid(r.switcher:AddChild(child)),"could not restore native wheel hierarchy")
      restore_slot(child,r.slots[i])
    end
    r.ability:SetRenderTranslation(r.abilityTranslation)
    r.consumable:SetRenderTranslation(r.consumableTranslation)
    r.switcher:SetRenderTranslation(r.switcherTranslation)
    r.switcher:SetActiveWidgetIndex(r.activeIndex)
    record=nil
  end
  local function restore_prompts()
    for id,p in pairs(prompts) do
      if env.valid(p.widget) then p.widget:SetRenderOpacity(p.opacity) end
      prompts[id]=nil
    end
  end
  function api:HidePrompt(w)
    return pcall(function()
      if not env.valid(w) then return end
      for id,p in pairs(prompts) do if not env.valid(p.widget) then prompts[id]=nil end end
      local id=env.fullname(w)
      if not prompts[id] then prompts[id]={widget=w,opacity=assert(tonumber(w:GetRenderOpacity()))} end
      if w:GetRenderOpacity()~=0.0 then w:SetRenderOpacity(0.0) end
    end)
  end
  function api:RestoreAll()
    return pcall(function() restore_layout(); restore_prompts() end)
  end
  function api:Update(hud,switcher,ability,consumable,showBoth,ax,ay,cx,cy)
    local ok,err=pcall(function()
      if record and (not env.same(record.hud,hud) or not env.same(record.switcher,switcher)
          or not env.same(record.ability,ability) or not env.same(record.consumable,consumable)) then
        restore_layout()
      end
      if not showBoth then restore_layout(); restore_prompts(); return end
      if not record then
        assert(env.same(env.parent(ability),switcher) and env.same(env.parent(consumable),switcher),
          "native wheel hierarchy unavailable; rebuild HUD before enabling both wheels")
        assert(switcher:GetChildrenCount()==2,"unexpected native switcher child count")
        local owner=env.parent(switcher)
        assert(env.valid(owner),"switcher parent unavailable")
        local order={switcher:GetChildAt(0),switcher:GetChildAt(1)}
        assert((env.same(order[1],ability) and env.same(order[2],consumable))
          or (env.same(order[1],consumable) and env.same(order[2],ability)),"unexpected wheel order")
        -- Copy scalar state before any mutation; never retain struct wrappers
        -- belonging to slots that are about to be destroyed.
        record={hud=hud,switcher=switcher,ability=ability,consumable=consumable,owner=owner,
          order=order,slots={slot_state(order[1]),slot_state(order[2])},activeIndex=switcher:GetActiveWidgetIndex(),
          abilityTranslation=translation(ability),consumableTranslation=translation(consumable),switcherTranslation=translation(switcher)}
      end
      if env.same(env.parent(ability),switcher) then
        assert(switcher:RemoveChild(ability)~=false,"could not detach ability wheel")
      end
      if not env.same(env.parent(ability),record.owner) then
        assert(env.valid(record.owner:AddChild(ability)),"could not attach ability wheel beside switcher")
      end
      -- Consumables stays in the native switcher; the ability wheel is its sibling.
      if switcher:GetActiveWidgetIndex()~=0 then switcher:SetActiveWidget(consumable) end
      set_translation(ability,ax,ay)
      set_translation(consumable,0,0)
      set_translation(switcher,cx,cy)
    end)
    if not ok and record then pcall(restore_layout) end
    return ok,err
  end
  return api
end
