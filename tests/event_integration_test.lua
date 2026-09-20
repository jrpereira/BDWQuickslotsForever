local f=assert(io.open('Scripts/main.lua','rb')); local source=f:read('*a');f:close()
local a=assert(source:find('local function update_hud_once()',1,true))
local b=assert(source:find('-- Mod Menu Apply owns configuration changes.',a,true))
local jobs,hooks,created={},{},{}
local input,hud,cleanup=0,0,0
local hudObject={}
local delays={}
local e={VisualEpoch=0,Config={Enabled=1},Enhanced={ready=false},scripts='Scripts',
  ExecuteInGameThread=function(fn) jobs[#jobs+1]=fn end,
  log=function() end,valid=function(o) return o~=nil end,fullname=function() return 'hud' end,
  ShortcutTargets={GetHUD=function()return hudObject end,SetHUD=function()end,Invalidate=function()end},
  get_live=function()return hudObject end,object_path=function()return '/Engine/Transient.HUD' end,
  request_wheel_setup=function()hud=hud+1 end,IndicatorSetup={Request=function()end,Invalidate=function()end},FormatSetup={Invalidate=function()end},
  apply_hud=function() return true end,refresh_hud_visuals=function() return true end,
  RegisterHook=function(path,pre,post) hooks[path]=post end,
  NotifyOnNewObject=function(path,fn) created[path]=fn end,
  LoopAsync=function() error("Repeating timer forbidden") end,
  ExecuteWithDelay=function(ms,fn) delays[#delays+1]=fn end,
  NativeKeys={Prune=function() end},WheelLayout={RestoreAll=function() return true end},RadialPaths={Invalidate=function() end,Visit=function()end},PromptPaths={Invalidate=function() end},
  update_native_action_gates=function() cleanup=cleanup+1;return true end}
e.enhanced_input_step=function()
  input=input+1;e.Enhanced.ready=true
  hooks['/Script/EnhancedInput.EnhancedInputSubsystemInterface:AddMappingContext']()
  return true
end
e.request_recovery=function() e.RecoveryWork:Request('input') end
setmetatable(e,{__index=_G})
assert(load(source:sub(a,b-1),'actual-maintenance','t',e))()
local function tick() local job=table.remove(jobs,1);if job then job() end end
tick();assert(input==1 and hud==1 and cleanup==1)
for i=1,1000 do tick() end
assert(input==1 and hud==1,'actual maintenance must remain idle')
hooks['/Script/Engine.PlayerController:ClientRestart']();tick()
assert(input==2 and hud==1)
hooks['/Script/EnhancedInput.EnhancedInputSubsystemInterface:RemoveMappingContext']();tick()
assert(input==3 and hud==1,'mapping changes do not rescan HUD')
e.request_recovery();e.RecoveryWork:Invalidate();e.reset_world_visuals();table.remove(jobs,1)()
assert(input==3 and hud==1,'cancel departing-world job')
e.request_recovery();tick();assert(input==4 and hud==1)
e.Config.Enabled=0;assert(#jobs==0 and #delays==0,'idle must have no callbacks scheduled')
print('PASS: actual main maintenance idle, lifecycle events, isolated mapping repair and stale-world cancellation')
