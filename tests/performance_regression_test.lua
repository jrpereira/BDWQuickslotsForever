local f=assert(io.open("Scripts/main.lua","rb")); local source=f:read("*a"); f:close()
local function section(first,last)
  local start=assert(source:find(first,1,true))
  local finish=assert(source:find(last,start, true))
  return source:sub(start,finish-1)
end
local auto=section('local function update_hud_once()','-- Mod Menu Apply owns configuration changes.')
assert(auto:find('delay=ExecuteWithDelay',1,true))
assert(not source:find('LoopAsync(',1,true))
assert(not source:find('RecoveryWork:Tick()',1,true))
assert(not auto:find('InputLifecycleBudget',1,true))
dofile('tests/event_work_test.lua')
local reconfigure=section('local function reconfigure_from_text(now)','local notificationOk,notificationError=')
assert(load([[
local BINDING_GROUPS={"Ability","Consumable"}
local Config={Enabled=1,RemoveDefinedActionBindings=0}
local Enhanced={ready=true}
local WheelLayout={RestoreAll=function() return true end}
local restarted,closeCalls=0,0
local function load_config(_) return {Enabled=0,RemoveDefinedActionBindings=0} end
local function valid(_) return false end
local function live_subsystem() return nil end
local function clear_bridge_bindings() closeCalls=closeCalls+1; return false,"still-owned subscription" end
local function RestartCurrentMod() restarted=restarted+1 end
local function log(_) end
local FormatSetup={Invalidate=function()end}
local RecoveryWork={Request=function()end}
local LastConfigText,PendingConfigBaseline
]]..reconfigure..[[
reconfigure_from_text("master off")
assert(closeCalls==1 and restarted==0)
print("PASS: failed Close prevents restart")
]],"restart-review"))()
assert(load([[
local BINDING_GROUPS={"Ability","Consumable"}
local Config={Enabled=1,RemoveDefinedActionBindings=0,ShowBothWheels=1}
local Enhanced={ready=true}
local closeCalls=0
local function load_config(_) return {Enabled=1,RemoveDefinedActionBindings=0,ShowBothWheels=0} end
local function valid(_) return false end
local function live_subsystem() return nil end
local function clear_bridge_bindings() closeCalls=closeCalls+1; return true end
local function refresh_hud_visuals() end
local function request_recovery() end
local function log(_) end
local FormatSetup={Invalidate=function()end}
local RecoveryWork={Request=function()end}
local LastConfigText,PendingConfigBaseline
]]..reconfigure..[[
assert(reconfigure_from_text("visual option only"))
assert(closeCalls==0 and Enhanced.ready==true)
print("PASS: visual-only edits preserve input")
]],"config-review"))()

assert(not source:find(':Rebuild All',1,true))
assert(not source:find('ExecuteWithDelay(1,',1,true))
dofile('tests/widget_setup_test.lua')
