-- Fixed, immediate inventory keys. Gameplay Tap/Hold bindings are independent.
-- No timers, mapping mutations, or UObject references survive between callbacks.
return function(api)
  local state={generation=0,pending=false}
  function state:Invalidate() self.generation=self.generation+1 end
  local function pressed(slot)
    -- Pure Lua gate: ordinary gameplay presses do not queue work or scan objects.
    if state.pending or not api.allowed() then return end
    local generation=state.generation
    state.pending=true
    local ok,err=pcall(api.queue,function()
      state.pending=false
      if generation~=state.generation or not api.allowed() then return end
      -- assign resolves the live overlay and checks IsActivated on the game thread.
      local called,assigned,detail=pcall(api.assign,slot)
      if not called then api.log("Inventory assignment failed: "..tostring(assigned))
      elseif not assigned and detail then api.log("Inventory assignment failed: "..tostring(detail)) end
    end)
    if not ok then state.pending=false;api.log("Inventory input dispatch failed: "..tostring(err)) end
  end
  -- Slot order matches native Left, Top, Right, Bottom. Native gamepad D-pad
  -- bindings remain owned by CommonUI; registering them again could double-fire.
  for slot,keys in ipairs({{0x31,0x25},{0x32,0x26},{0x33,0x27},{0x34,0x28}}) do
    for _,key in ipairs(keys) do api.register(key,function() pressed(slot) end) end
  end
  return state
end
