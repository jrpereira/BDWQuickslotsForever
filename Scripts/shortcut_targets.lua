-- Constant-size HUD lookup on key presses. Global discovery occurs once per
-- invalidation, and never falls back to Blueprint templates or unrelated panels.
return function(e)
  local hud
  local discovered=false
  local api={}
  function api:Invalidate() hud=nil;discovered=false end
  function api:SetHUD(o)
    if e.valid(o) and e.live(o) then hud=o;discovered=true end
  end
  function api:GetHUD() if e.valid(hud) then return hud end end
  function api:Get(group,slot)
    if not e.valid(hud) and not discovered then
      discovered=true
      self:SetHUD(e.discover())
    end
    if not e.valid(hud) then return end
    -- Read the known owner's current fields: rebuilt children replace these
    -- references without requiring another object-array scan.
    local wheel=e.wheel(hud,group)
    if not e.valid(wheel) then return end
    local button=e.button(wheel,slot)
    if e.valid(button) then return button end
  end
  return api
end
