local f=assert(io.open('Scripts/main.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function bindings_widget(',1,true))
local b=assert(s:find('local PathCache=',a,true))
local c=assert(s:find('local function connect_radial(',b,true))
local d=assert(s:find('local function same(',c,true))
local assigned={};local directions={'Left','Top','Right','Bottom'}
local function wheel(n,nested)
 local w={}
 for _,dir in ipairs(directions) do local v={id=n..dir};w[dir]=nested and {Button=v} or v end
 return w
end
local hudA,hudC=wheel('hudAbility'),wheel('hudConsumable')
local radials={wheel('floatOne',true),wheel('floatTwo',true)}
local env={Config={InteractionMode=0},SLOT_WIDGET=directions,valid=function(o)return o~=nil end,safe=function(o,k)return o and o[k]end,
 Enhanced={ready=true},PersistentInput={actions={}},NativeKeys={Set=function(_,w,act)if not w or not act then return false end;assigned[w.id]=act;return true end},
 RadialPaths={Visit=function(_,fn)for _,w in ipairs(radials)do fn(w)end end},log=function()end}
for _,g in ipairs({'Ability','Consumable'})do for i=1,4 do env.PersistentInput.actions[g..i]={name='IA_'..g..'Slot'..i}end end
setmetatable(env,{__index=_G})
local hud,radial=assert(load(s:sub(a,b-1)..s:sub(c,d-1)..'\nreturn override_icons,connect_radial','wheel-wiring','t',env))()
assert(hud({WBP_AA_Quickslots_Bindings=hudA},{WBP_HUD_Quickslots_Bindings=hudC})==8)
for _,w in ipairs(radials)do assert(radial(w)==true)end
for i,dir in ipairs(directions)do
 assert(assigned['hudAbility'..dir]==env.PersistentInput.actions['Ability'..i])
 assert(assigned['hudConsumable'..dir]==env.PersistentInput.actions['Consumable'..i])
 for _,prefix in ipairs({'floatOne','floatTwo'})do assert(assigned[prefix..dir]==env.PersistentInput.actions['Ability'..i])end
end
local pending=radials[2].Bottom;radials[2].Bottom=nil
assert(radial(radials[2])=='children_missing','partial floating wheel must request further readiness work')
radials[2].Bottom=pending;for _,w in ipairs(radials)do assert(radial(w)==true)end
assert(not s:find('RegisterKeyBind',1,true) and not s:find('native_key_icons.lua',1,true) and not s:find('inventory_hints.lua',1,true))
print('PASS both HUD wheels and both floating Ability Wheels use matching persistent actions; old assignment/icon adapters are not loaded')
