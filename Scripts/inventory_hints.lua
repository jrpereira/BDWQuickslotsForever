-- Event-driven assignment preview labels; no polling or retained widget wrappers.
return function(api)
  local state={pending=false,generation=0}
  function state:Invalidate() self.generation=self.generation+1 end
  function state:Request()
    if not api.enabled() then return end
    -- Keep the latest activation request even when a previous close invalidated
    -- the queued refresh; that queued job will resolve only current live state.
    self.requestGeneration=self.generation
    if self.pending then return end
    self.pending=true
    local ok,err=pcall(api.queue,function()
      self.pending=false
      if self.requestGeneration~=self.generation or not api.enabled() then return end
      local refreshed,why=pcall(function()
        if not api.valid(api.overlay()) then return end
        local inventory=api.inventory()
        if not api.valid(inventory) then return end
        local wheel=api.get(inventory,'WBP_Inventory_Quickslots')
        local panel=api.valid(wheel) and api.get(wheel,'ControlPanel') or nil
        if not api.valid(panel) then return end
        local display=api.display and api.display() or nil
        for slot,direction in ipairs({'Left','Top','Right','Bottom'}) do
          -- Always 1-4 and never a Hold underline, regardless of gameplay config.
          api.set_key(api.get(panel,direction),0x30+slot,0,display)
        end
      end)
      if not refreshed then api.log('Inventory preview update failed: '..tostring(why)) end
    end)
    if not ok then self.pending=false;api.log('Inventory preview dispatch failed: '..tostring(err)) end
  end
  return state
end
