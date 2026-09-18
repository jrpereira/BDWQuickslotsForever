local scan=0
local function button()return {valid=true}end
local function hud()return {valid=true,live=true,Ability={button(),button(),button(),button()},Consumable={button(),button(),button(),button()}}end
local current=hud()
local cache=dofile('Scripts/shortcut_targets.lua')({valid=function(o)return o and o.valid end,
 live=function(o)return o.live end,discover=function()scan=scan+1;return current end,
 wheel=function(h,g)return h[g]end,button=function(w,i)return w[i]end})
current.Ability.valid=true;current.Consumable.valid=true
for i=1,1000 do assert(cache:Get('Ability',1)==current.Ability[1]);assert(cache:Get('Consumable',4)==current.Consumable[4])end
assert(scan==1,'2000 inputs must perform only bootstrap discovery')
current.Ability[1].valid=false;assert(cache:Get('Ability',1)==nil and scan==1)
current.Ability[1]=button();assert(cache:Get('Ability',1)==current.Ability[1],'rebuilt field reconnects without global search')
current.valid=false;assert(cache:Get('Ability',1)==nil and scan==1)
current=hud();current.Ability.valid=true;current.Consumable.valid=true
cache:SetHUD(current);assert(cache:Get('Ability',1)==current.Ability[1] and scan==1)
cache:Invalidate();assert(cache:Get('Ability',1)==current.Ability[1] and scan==2)
cache:Invalidate();current=nil;assert(cache:Get('Ability',1)==nil);assert(cache:Get('Ability',1)==nil and scan==3)
print('PASS cached action targets: no per-input discovery, reject destroyed targets, resolve rebuilt fields, new HUD/teardown and negative discovery cache')
