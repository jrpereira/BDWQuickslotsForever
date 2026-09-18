local jobs,timers={},{}
local selected,enabled=true,true
local manager={valid=true};local panel={valid=true,active=true};local overlay
local prepared,removed,scans=0,0,0;local ready=true
local nav=dofile('Scripts/inventory_navigation.lua')({valid=function(o)return o and o.valid end,
 same=function(a,b)return a==b end,enabled=function()return enabled end,selected=function()return selected end,
 panel=function()return panel end,active=function(p)return p.active end,
 find_overlay=function()scans=scans+1;return overlay end,
 prepare=function(o)assert(o.valid and panel.active);prepared=prepared+1;return ready end,
 deactivate=function()removed=removed+1 end,queue=function(fn)jobs[#jobs+1]=fn end,
 delay=function(ms,fn)assert(ms==100);timers[#timers+1]=fn end,log=function()end})
local function step()local fn=table.remove(jobs,1) or table.remove(timers,1);if fn then fn();return true end end
local function settle()for i=1,40 do if not step()then return end end;error('did not settle')end
nav:Resume();assert(#timers==0 and scans==0,'general wakeup cannot discover inventory')
nav:OnTab(manager,'UI.Menu.HUB.Map');settle();assert(prepared==0 and scans==0 and removed==0)
nav:OnTab(manager,'UI.Menu.HUB.Inventory');nav:OnTab(manager,'UI.Menu.HUB.Inventory')
assert(#timers==1);settle();assert(scans==1 and prepared==0 and #timers==0,'absent overlay waits for creation')
overlay={valid=true};nav:OnOverlay(overlay);settle();assert(prepared==1)
panel.active=false;nav:CheckClosed();settle();assert(removed==1)
nav:OnOverlay(overlay);nav:Resume();assert(#timers==0 and scans==1,'closed inventory does not prepare')
panel={valid=true,active=true};nav:OnTab(manager,'UI.Menu.HUB.Inventory');settle();assert(prepared==2)
ready=false;nav:Resume()
for i=1,6 do nav:OnTab(manager,'UI.Menu.HUB.Inventory');assert(step());assert(step())end
assert(prepared==8 and #timers==0,'duplicate pending events cannot extend readiness budget')
ready=true;nav:OnTab(manager,'UI.Menu.HUB.Inventory');nav:OnTab(manager,'UI.Menu.HUB.Crafting');settle()
assert(prepared==8 and removed==2,'departing tab cancels stale work')
nav:OnTab(manager,'UI.Menu.HUB.Inventory');panel.valid=false;settle();assert(prepared==8 and #timers==0)
panel={valid=true,active=true};nav:OnTab(manager,'UI.Menu.HUB.Inventory');nav:Invalidate();settle();assert(prepared==8)
print('PASS Inventory navigation: no unrelated work, selected active panel only, late S overlay, close/reopen, bounded dependencies and stale cancellation')
