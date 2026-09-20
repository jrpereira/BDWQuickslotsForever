local f=assert(io.open('Scripts/main.lua','rb'));local s=f:read('*a');f:close()
local a=assert(s:find('local NativeActionTargets={',1,true));local b=assert(s:find('local function loaded_input_actions()',a,true))
local config={Enabled=1,InteractionMode=0}
local targets,action,setInventory=assert(load(s:sub(a,b-1)..'\nreturn NativeActionTargets,action_should_be_gated,function(v) InventoryActionGateOpen=v end','targets','t',
 setmetatable({Config=config,valid=function(o)return o~=nil end,fullname=function(o)return o end},{__index=_G})))()
local m=assert(io.open('mod_settings.ini','rb'));local metadata=m:read('*a');m:close()
assert(#targets==6)
assert(not metadata:find('[Setting.RemoveDefinedActionBindings]',1,true),'gating is not a menu option')
assert(not s:find('RemoveDefinedActionBindings',1,true),'legacy option must not gate runtime code')
assert(not s:find('SettingBehavior=2',1,true) and not s:find("KeyName=FName('None')",1,true),
  'native mappings must never be blanked')
for _,name in ipairs(targets) do
 local candidate='InputAction /Game/Input/'..name..'.'..name
 assert(action(candidate) and not action(candidate..'_Other'))
end
config.InteractionMode=1
for i,name in ipairs(targets)do
 local candidate='InputAction /Game/Input/'..name..'.'..name
 assert(action(candidate)==(i>4),'Selective preserves native slots and gates native Swap')
end
config.InteractionMode=0;setInventory(true)
for i,name in ipairs(targets)do
 assert(action('InputAction /Game/Input/'..name..'.'..name)==(i>4),'Inventory restores native slot actions only')
end
config.Enabled=0;setInventory(false)
for _,name in ipairs(targets)do assert(not action('InputAction /Game/Input/'..name..'.'..name))end
for _,name in ipairs({'IA_QuickslotSwap','IA_QuickslotToggle','Jump'}) do assert(not action(name)) end
print('PASS: six exact native actions, mode and Inventory scoped gates, no mapping mutation or guessed aliases')
