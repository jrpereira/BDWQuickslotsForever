-- Inventory work is scoped to a selected, live Inventory panel. The assignment
-- context belongs to its S overlay; an absent overlay waits for its creation.
return function(e)
  local manager,panel,overlay
  local epoch=0
  local pending
  local api={}
  function api:Invalidate()
    epoch=epoch+1;pending=nil;manager=nil;panel=nil;overlay=nil
  end
  local function selected()
    return e.enabled() and e.valid(manager) and e.selected(manager)
  end
  local function request()
    if pending or not e.valid(manager) or not e.enabled() then return end
    local ticket={epoch=epoch,left=6,discovered=false}
    pending=ticket
    local function current() return pending==ticket and epoch==ticket.epoch end
    local function stop() if current() then pending=nil end end
    local schedule
    schedule=function()
      local ok,err=pcall(e.delay,100,function()
        if not current() then return end
        local queued,why=pcall(e.queue,function()
          if not current() then return end
          local success,done=pcall(function()
            if not selected() then return true end
            if not e.valid(panel) then panel=e.panel(manager) end
            -- Invalid/closed panel is not a readiness retry.
            if not e.valid(panel) or not e.active(panel) then return true end
            if not e.valid(overlay) and not ticket.discovered then
              ticket.discovered=true;overlay=e.find_overlay()
            end
            if not e.valid(overlay) then return true end
            return e.prepare(overlay)
          end)
          if not success then stop();e.log('Inventory setup failed: '..tostring(done));return end
          if done~=true and ticket.left>1 then ticket.left=ticket.left-1;schedule()
          else stop() end
        end)
        if not queued then stop();e.log('Inventory dispatch failed: '..tostring(why)) end
      end)
      if not ok then stop();e.log('Inventory scheduling failed: '..tostring(err)) end
    end
    schedule()
  end
  function api:OnTab(owner,tag)
    if tag~='UI.Menu.HUB.Inventory' then
      local hadInventory=e.valid(manager)
      if not hadInventory then return end -- preserve an already queued exit
      self:Invalidate()
      if hadInventory then
        local generation=epoch
        e.queue(function() if epoch==generation then e.deactivate() end end)
      end
      return
    end
    if not e.valid(owner) or not e.enabled() then return end
    if not e.valid(manager) or not e.same(manager,owner) then
      local candidate=overlay
      self:Invalidate();manager=owner
      if e.valid(candidate) then overlay=candidate end
    end
    if not pending then panel=nil end
    request()
  end
  function api:OnOverlay(o)
    if not e.valid(o) then return end
    overlay=o
    request()
  end
  function api:Resume() request() end
  function api:CheckClosed()
    local generation=epoch
    e.queue(function()
      if epoch~=generation or not e.valid(manager) then return end
      if not selected() or (e.valid(panel) and not e.active(panel)) then
        self:Invalidate();e.deactivate()
      end
    end)
  end
  return api
end
