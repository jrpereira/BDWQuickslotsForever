local f=assert(io.open('Scripts/main.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function install_input_gate_hooks()',1,true))
local b=assert(s:find('\ninstall_input_gate_hooks()',a,true))
local hooks={};local opens,closes=0,0
local env={RegisterHook=function(path,pre,post)hooks[path]={pre,post}end,
 unwrap=function(o)return o end,valid=function(o)return o~=nil end,
 fullname=function(o)return o.class..' '..o.path end,
 sync_inventory_context=function(o)assert(o.class=='WBP_Inventory_QuickslotBindOverlay_C');opens=opens+1 end,
 PersistentInput={DeactivateInventory=function()closes=closes+1 end},
 record_blocking_widget=function()end,blocks_gameplay_widget=function()return false end,
 request_recovery=function()end,sync_blocking_widgets_once=function()end,report_input_gate=function()end,
 log=function()end,InputGate={},bool_value=function(v)return v end}
setmetatable(env,{__index=_G})
assert(load(s:sub(a,b-1)..'\ninstall_input_gate_hooks()','inventory-hooks','t',env))()
local activate=hooks['/Script/CommonUI.CommonActivatableWidget:ActivateWidget']
local deactivate=hooks['/Script/CommonUI.CommonActivatableWidget:DeactivateWidget']
local menu={class='WBP_Hub_NewInventory_C',path='/menu'}
activate[1](menu);activate[2](menu);assert(opens==0,'ordinary inventory is not assignment mode')
local overlay={class='WBP_Inventory_QuickslotBindOverlay_C',path='/overlay'}
activate[1](overlay);assert(opens==1,'prepare before CommonUI activation')
activate[2](overlay);assert(opens==2,'idempotent post-activation coverage')
deactivate[1](menu);assert(closes==0)
deactivate[1](overlay);assert(closes==1,'remove on overlay close')
print('PASS actual inventory hooks: only S overlay applies context, preparation precedes activation, close removes it')

local a=assert(s:find('sync_inventory_context=function(overlay)',1,true))
local b=assert(s:find('local function clear_bridge_bindings()',a,true))
local attached,activated,deactivated=0,0,0
local active=false
local ctxEnv=setmetatable({Config={Enabled=1},Enhanced={sub={}},
 valid=function(o)return o~=nil end,
 PersistentInput={AttachInventory=function()attached=attached+1;return true end,
 OpenInventory=function()activated=activated+1;return true end,
 DeactivateInventory=function()deactivated=deactivated+1 end}}, {__index=_G})
local sync=assert(load(s:sub(a,b-1)..'\nreturn sync_inventory_context','inventory-scoped-prepare','t',ctxEnv))()
assert(sync(nil) and attached==0)
local overlay={IsActivated=function()return active end}
assert(sync(overlay) and attached==1 and activated==0 and deactivated==1)
active=true;assert(sync(overlay) and activated==1)
assert(not s:find("RecoveryWork:Request('inventory')",1,true) and not s:find("RecoveryWork:AfterReady('inventory')",1,true))
print('PASS actual inventory preparation: specific valid S overlay only, inactive attach versus active application, no general recovery lane')
