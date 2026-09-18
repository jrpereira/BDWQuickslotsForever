-- Reproduce ordering/failure cases against production modules and Apply code.
local function shift(q) local fn=assert(table.remove(q,1));fn() end
do
  local jobs,timers,runs={},{},{}
  local work=dofile('Scripts/event_work.lua')({attempts=3,enabled=function()return true end,
    queue=function(fn)jobs[#jobs+1]=fn end,delay=function(_,fn)timers[#timers+1]=fn end,
    log=function()end,run=function(name)runs[name]=(runs[name] or 0)+1;return name~='cleanup' end})
  work:Request('cleanup');shift(jobs)
  work:Request('input');assert(#jobs==1,'fresh input cannot wait for cleanup timer');shift(jobs)
  assert(runs.input==1 and runs.cleanup==1,'fresh work cannot consume another task retry')
  for i=1,100 do work:Request('cleanup') end
  shift(timers);shift(jobs);shift(timers);shift(jobs)
  assert(runs.cleanup==3 and #timers==0 and #jobs==0,'duplicates preserve finite budget')
end
do
  local jobs,timers={},{};local removed=0;local manager,panel,overlay={},{},{}
  local nav=dofile('Scripts/inventory_navigation.lua')({valid=function(o)return o~=nil end,
    same=function(a,b)return a==b end,enabled=function()return true end,selected=function()return true end,
    panel=function()return panel end,active=function()return true end,find_overlay=function()return overlay end,
    prepare=function()return true end,deactivate=function()removed=removed+1 end,log=function()end,
    queue=function(fn)jobs[#jobs+1]=fn end,delay=function(_,fn)timers[#timers+1]=fn end})
  nav:OnTab(manager,'UI.Menu.HUB.Inventory');shift(timers);shift(jobs)
  nav:OnTab(manager,'UI.Menu.HUB.Map');nav:OnTab(manager,'UI.Menu.HUB.Crafting');shift(jobs)
  assert(removed==1,'successive non-Inventory tabs must preserve cleanup')
  nav:OnTab(manager,'UI.Menu.HUB.Inventory');shift(timers);shift(jobs)
  nav:OnTab(manager,'UI.Menu.HUB.Map');nav:OnTab(manager,'UI.Menu.HUB.Inventory');shift(jobs)
  assert(removed==1,'old exit cannot deactivate newly reopened Inventory')
  shift(timers);shift(jobs)
end
do
  local jobs,timers={},{};local runs=0
  local setup=dofile('Scripts/widget_setup.lua')({valid=function(o)return o and o.valid end,
    key=function()return 'HUD' end,enabled=function()return true end,log=function()end,
    queue=function(fn)jobs[#jobs+1]=fn end,delay=function(_,fn)timers[#timers+1]=fn end,
    run=function()runs=runs+1;return true end})
  local old,new={valid=true},{valid=true}
  setup:Request(old);old.valid=false;setup:Request(new)
  shift(timers);assert(#jobs==0,'superseded delay must do nothing')
  shift(timers);shift(jobs);assert(runs==1,'replacement must get its own setup')
  setup:Request(new);assert(#timers==0,'same completed context is still deduplicated')
end
do
  local f=assert(io.open('Scripts/main.lua'));local source=f:read('*a');f:close()
  local a=assert(source:find('local function reconfigure_from_text(now)',1,true))
  local b=assert(source:find('local notificationOk,notificationError=',a,true))
  local old={Enabled=1,Ability1=49,ShowBothWheels=1}
  local new={Enabled=1,Ability1=50,ShowBothWheels=0}
  local fail=true;local closes,input,hud,inventory,suppress=0,0,0,0,0
  local e=setmetatable({Config=old,LastConfigText='old',BINDING_GROUPS={'Ability','Consumable'},
    PersistentInput={Validate=function()return true end},Enhanced={ready=true},load_config=function(text)return text=='old' and old or new end,
    valid=function()return false end,live_subsystem=function()end,
    clear_bridge_bindings=function()closes=closes+1;return true end,
    RequestSuppressionSnapshot=function()end,remove_native_conflicts=function()
      suppress=suppress+1;return true end,
    FormatSetup={Invalidate=function()end},RecoveryWork={Invalidate=function()end,
      Request=function(_,name)assert(name=='hud');hud=hud+1 end},
    InventoryNavigation={Resume=function()inventory=inventory+1 end},
    request_recovery=function()input=input+1;if fail then error("temporary recovery rejection")end end,log=function()end}, {__index=_G})
  local apply=assert(load(source:sub(a,b-1)..'\nreturn reconfigure_from_text','actual-apply','t',e))()
  assert(not pcall(apply,'new') and e.LastConfigText=='old' and e.PendingConfigBaseline==old)
  fail=false;assert(apply('new'))
  assert(e.LastConfigText=='new' and not e.PendingConfigBaseline and hud==1 and closes==1)
  -- A visual-only change must not wake input, Inventory or suppression work.
  local beforeInput,beforeInventory,beforeSuppress=input,inventory,suppress
  local visual={};for k,v in pairs(new)do visual[k]=v end;visual.ShowBothWheels=1
  e.load_config=function()return visual end
  assert(apply('visual'))
  assert(input==beforeInput and inventory==beforeInventory and suppress==beforeSuppress and hud==2)
  local legacy={};for k,v in pairs(visual)do legacy[k]=v end
  legacy.RemoveDefinedActionBindings=0;e.load_config=function()return legacy end
  assert(apply('legacy option'))
  assert(input==beforeInput and inventory==beforeInventory and suppress==beforeSuppress and hud==2,
    'ignored legacy option must not wake input, suppression or wheel formatting')
  -- A dirty failed Apply must also reconcile a user's reversion to the last text.
  local callback;local calls=0
  dofile('Scripts/config_notifications.lua')({subscribe=function(_,fn)callback=fn end,
    queue=function(fn)fn()end,read=function()return '[General]\n[Bindings]' end,
    current=function()return '[General]\n[Bindings]' end,dirty=function()return true end,
    apply=function()calls=calls+1;return true end,log=function()end})
  callback();assert(calls==1,'dirty configuration must not be skipped on equal text')
end
print('PASS audit regressions: independent retries, navigation cleanup, pending replacement, failed Apply recovery and scoped visual Apply')
