local f=assert(io.open('Scripts/main.lua','rb'));local s=f:read('*a');f:close()
local a=assert(s:find('local SuppressionTargets={',1,true));local b=assert(s:find('local function remove_native_conflicts()',a,true))
local targets,action,mapping=assert(load(s:sub(a,b-1)..'\nreturn SuppressionTargets,action_is_defined_here,mapping_name_is_defined_here','targets','t',
 setmetatable({valid=function(o)return o~=nil end,fullname=function(o)return o end},{__index=_G})))()
local m=assert(io.open('mod_settings.ini','rb'));local metadata=m:read('*a');m:close()
assert(#targets==6)
assert(not metadata:find('[Setting.RemoveDefinedActionBindings]',1,true),'suppression is not a menu option')
assert(not s:find('RemoveDefinedActionBindings',1,true),'legacy option must not gate runtime code')
assert(not s:find('UnMapPlayerKey',1,true) and not s:find('SavedKeyboardBindings',1,true) and not s:find('clear_rebel_map',1,true),'no persistent binding mutation')
for _,t in ipairs(targets) do
 assert(action('InputAction /Game/Input/'..t.action..'.'..t.action))
 assert((not t.row or mapping(t.row)) and mapping(t.action))
 assert(t.row and #t.row>0,'each target needs a recognized row')
 assert(not action('InputAction /Game/Input/'..t.action..'_Other'))
end
for _,name in ipairs({'IA_QuickslotSwap','IA_QuickslotToggle','Jump'}) do
 assert(not mapping(name) and not action(name),'unlisted actions must be preserved')
end
assert(not mapping(''),'unknown mapping names must not match')
print('PASS: six explicit actions, automatic suppression, exact identity, no guessed swap aliases')
