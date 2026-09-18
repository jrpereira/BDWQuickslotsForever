local callback,jobs,reads,applied,logs=nil,{},0,0,{}
local committed='[General]\nEnabled=1\n[Bindings]\nAbility1=49'
local current=committed
local factory=dofile('Scripts/config_notifications.lua')
factory({subscribe=function(id,fn)assert(id=='QuickslotsForever');callback=fn end,
 queue=function(fn)jobs[#jobs+1]=fn end,
 read=function()reads=reads+1;return committed end,current=function()return current end,
 apply=function(text)applied=applied+1;current=text;return true end,
 log=function(s)logs[#logs+1]=s end})
assert(reads==0 and #jobs==0,'subscription must not monitor files')
callback();callback();assert(#jobs==1 and reads==0)
table.remove(jobs,1)();assert(reads==1 and applied==0)
committed=committed..'\nAbility2=50';callback();table.remove(jobs,1)()
assert(reads==2 and applied==1)
committed='incomplete';callback();table.remove(jobs,1)();assert(applied==1 and #logs==1)

-- Exercise the actual DMM v1 subscriber delivery without another Lua state's callbacks.
local shared,handlers={},{}
local env=setmetatable({ModRef={GetSharedVariable=function(_,k)return shared[k]end,
 SetSharedVariable=function(_,k,v)shared[k]=v end},RegisterConsoleCommandHandler=function(k,fn)handlers[k]=fn end}, {__index=_G})
local api=assert(loadfile('Scripts/dmm_api.lua','t',env))()
local count=0
api.subscribe('QuickslotsForever',function(values,changes)
 assert(values.Enabled==0 and changes.Enabled.old==1);count=count+1
end)
local command,handler=next(handlers)
shared[command..'.data']='1\n456e61626c6564 1 0\n'
assert(handler());assert(handler());assert(count==1,'duplicate revision is ignored')

local f=assert(io.open('Scripts/main.lua'));local source=f:read('*a');f:close()
assert(not source:find('local function watch()',1,true) and not source:find('ExecuteWithDelay(750',1,true))
assert(not source:find('RestartCurrentMod',1,true),'master toggles must not lose the DMM subscription')
local start=assert(source:find('local function reconfigure_from_text(now)',1,true))
local stop=assert(source:find('local notificationOk,notificationError=',start,true))
local state={ready=true};local closes,recoveries=0,0
local env2=setmetatable({Config={Enabled=1,RemoveDefinedActionBindings=1},Enhanced=state,
 snapshot_inventory_navigation=function()end,
 BINDING_GROUPS={'Ability','Consumable'},LastConfigText='old',
 load_config=function(text)return {Enabled=text=='on' and 1 or 0,RemoveDefinedActionBindings=1}end,
 NativeKeys={RestoreAll=function()return true end},WheelLayout={RestoreAll=function()return true end},
 PersistentInput={CloseInventory=function()end},Suppression={Restore=function()end},FormatSetup={Invalidate=function()end},RecoveryWork={Invalidate=function()end,Request=function()end},
 valid=function()return false end,live_subsystem=function()return nil end,
 clear_bridge_bindings=function()closes=closes+1;return true end,
 reset_world_visuals=function()end,request_recovery=function()recoveries=recoveries+1 end,log=function()end}, {__index=_G})
local apply=assert(load(source:sub(start,stop-1)..'\nreturn reconfigure_from_text','apply-in-place','t',env2))()
assert(apply('off') and env2.Config.Enabled==0 and not state.ready)
assert(apply('on') and env2.Config.Enabled==1 and closes==1 and recoveries==2)
print('PASS DMM Apply: no polling, coalesced one-time reads, malformed config isolation, actual subscriber revision handling and in-place master disable/enable')
