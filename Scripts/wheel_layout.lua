-- Own only the reversible dual-wheel layout. Input bindings are independent.
return function(env)
  local record
  local selection
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
  local function restore_selection()
    if selection and env.valid(selection.switcher) and env.valid(selection.widget)
        and env.same(env.parent(selection.widget),selection.switcher) then
      selection.switcher:SetActiveWidget(selection.widget)
    end
    selection=nil
  end
  local function focus_dual(wheel)
    local r=assert(record,'dual-wheel layout is not active')
    assert(env.same(wheel,r.primary) or env.same(wheel,r.secondary),'focused widget is not a configured wheel')
    local detached=env.same(wheel,r.primary) and r.secondary or r.primary
    if not env.same(env.parent(wheel),r.switcher) then
      local wheelOwner=env.parent(wheel)
      assert(env.same(wheelOwner,r.owner),'focused wheel has an unexpected parent')
      assert(wheelOwner:RemoveChild(wheel)~=false,'could not detach focused wheel from layout owner')
      local currentOwner=env.parent(detached)
      assert(env.same(currentOwner,r.switcher),'other wheel has an unexpected parent')
      assert(r.switcher:RemoveChild(detached)~=false,'could not detach prior focused wheel')
      assert(env.valid(r.switcher:AddChild(wheel)),'could not attach focused wheel to native switcher')
      assert(env.valid(r.owner:AddChild(detached)),'could not attach other wheel beside switcher')
    elseif env.same(env.parent(detached),r.switcher) then
      assert(r.switcher:RemoveChild(detached)~=false,'could not detach secondary wheel')
      assert(env.valid(r.owner:AddChild(detached)),'could not attach secondary wheel beside switcher')
    end
    if r.switcher:GetActiveWidgetIndex()~=0 then r.switcher:SetActiveWidget(wheel) end
    set_translation(wheel,0,0)
    if env.same(wheel,r.primary) then
      set_translation(r.switcher,r.px,r.py);set_translation(detached,r.sx,r.sy)
    else
      set_translation(r.switcher,r.sx,r.sy);set_translation(detached,r.px,r.py)
    end
    r.focused=wheel
  end
  function api:SelectWheel(switcher,wheel)
    return pcall(function()
      assert(env.valid(switcher) and env.valid(wheel) and env.same(env.parent(wheel),switcher),
        'Selected wheel is not a native switcher child')
      if selection and not env.same(selection.switcher,switcher) then restore_selection() end
      if not selection then
        selection={switcher=switcher,widget=switcher:GetChildAt(switcher:GetActiveWidgetIndex())}
      end
      local active=switcher:GetChildAt(switcher:GetActiveWidgetIndex())
      if not env.same(active,wheel) then switcher:SetActiveWidget(wheel) end
    end)
  end
  function api:FocusWheel(switcher,wheel)
    local ok,err=pcall(function()
      assert(record and env.same(record.switcher,switcher),'dual-wheel layout unavailable')
      focus_dual(wheel)
    end)
    if not ok and record then pcall(restore_layout) end
    return ok,err
  end
  function api:RestoreAll()
    return pcall(function() restore_layout(); restore_selection(); restore_prompts() end)
  end
  function api:Forget()
    -- World teardown: drop wrappers without dereferencing the departing tree.
    record=nil
    selection=nil
    prompts={}
  end
  function api:Update(hud,switcher,ability,consumable,showBoth,primary,secondary,px,py,sx,sy)
    local ok,err=pcall(function()
      if record and (not env.same(record.hud,hud) or not env.same(record.switcher,switcher)
          or not env.same(record.ability,ability) or not env.same(record.consumable,consumable)) then
        restore_layout()
      end
      if not showBoth then restore_layout(); restore_prompts(); return end
      assert((env.same(primary,ability) and env.same(secondary,consumable))
          or (env.same(primary,consumable) and env.same(secondary,ability)),
        "primary and secondary must identify the two native wheels")
      if record and not env.same(record.primary,primary) then restore_layout() end
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
          primary=primary,secondary=secondary,
          px=px,py=py,sx=sx,sy=sy,
          order=order,slots={slot_state(order[1]),slot_state(order[2])},activeIndex=switcher:GetActiveWidgetIndex(),
          abilityTranslation=translation(ability),consumableTranslation=translation(consumable),switcherTranslation=translation(switcher)}
      end
      record.px,record.py,record.sx,record.sy=px,py,sx,sy
      -- Initial focus is Primary. Later selection can exchange switcher membership
      -- without changing either wheel's configured screen position.
      focus_dual(record.focused or primary)
    end)
    if not ok and record then pcall(restore_layout) end
    return ok,err
  end
  return api
end
