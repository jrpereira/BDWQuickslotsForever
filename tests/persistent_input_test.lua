local objects,constructed,active,bindings={},0,{},{}
local function object(name)
 local o={name=name,valid=true,Mappings={},Triggers={}}
 function o:UnmapAll() self.Mappings={} end
 function o:MapKey(a,k) self.Mappings[#self.Mappings+1]={Action=a,Key=k,SettingBehavior=0} end
 objects[name]=o;return o
end
local function valid(o) return o and o.valid end
local sub=object('sub')
function sub:AddMappingContext(c,p,options) active[c]=p;self.lastOptions=options end
function sub:RemoveMappingContext(c) active[c]=nil end
local closeFail=false
local bridge={OpenInputComponent=function() return 5 end,
 CloseInputComponent=function() return not closeFail,'injected' end,
 BindAction=function(_,path,phase,fn) assert(phase=='Triggered');bindings[path]=fn;return 8 end}
local native={}
for _,d in ipairs({'Left','Top','Right','Bottom'}) do native[d]=object('IA_Quickslot_'..d) end
local api=dofile('Scripts/persistent_input.lua')({
 valid=valid,path=function(o)return o.name end,resolve=function(p)return objects[p]end,
 same=function(a,b)return a==b end,name=function(s)return s end,key=function(k)return k end,
 retain=function(_,name) if objects[name] then return objects[name] end;constructed=constructed+1;return object(name) end,
 each=function(t,fn)for i,v in ipairs(t)do fn(i,v)end end,
 bridge=function()return bridge end,initialize_identity=function()end,
 trigger=function(a,m,t)a.mode=m;a.threshold=t end,
 native_action=function(d)return native[d]end,present=function(c)return active[c]~=nil end,
})
local config={HoldThresholdMs=200};local defs={}
for _,g in ipairs({'Ability','Consumable'})do for i=1,4 do
 local f=g..i;config[f]='Key'..i;config[f..'Mode']=i%2;defs[#defs+1]={field=f}
end end
api:Configure(config);assert(constructed==9 and #api.contexts.gameplay.Mappings==8)
local original=api.actions.Ability1
local called=0
assert(api:Bind(object('input'),sub,defs,function()return function()called=called+1 end end))
assert(active[api.contexts.gameplay]==10000)
bindings.IA_AbilitySlot1();assert(called==1)
closeFail=true;assert(not api:Close() and api.target==5 and active[api.contexts.gameplay])
closeFail=false;assert(api:Close() and not active[api.contexts.gameplay])
config.Ability1='NewKey';config.Ability1Mode=0;config.HoldThresholdMs=400
api:Configure(config)
assert(constructed==9 and api.actions.Ability1==original and original.mode==0 and original.threshold==0.4)
assert(api.contexts.gameplay.Mappings[1].Key.KeyName=='NewKey')
for _,m in ipairs(api.contexts.gameplay.Mappings)do assert(m.SettingBehavior==2)end
local overlay=object('overlay');overlay.InputMappingPriority=7
assert(api:AttachInventory(overlay,sub))
assert(overlay.InputMapping==api.contexts.inventory and not active[api.contexts.inventory],
 'prepare an inactive overlay without activating gameplay mappings')
assert(api:OpenInventory(overlay,sub));local inventory=api.contexts.inventory
assert(constructed==10 and #inventory.Mappings==12 and active[inventory]==10002)
assert(sub.lastOptions.bForceImmediately and not sub.lastOptions.bNotifyUserSettings)
api:DeactivateInventory()
assert(not active[inventory] and overlay.InputMapping==inventory,'native close must retain next-open InputMapping')
assert(api:OpenInventory(overlay,sub) and active[inventory]==10002)
local expected={'One','Left','Gamepad_DPad_Left','Two','Up','Gamepad_DPad_Up',
 'Three','Right','Gamepad_DPad_Right','Four','Down','Gamepad_DPad_Down'}
for i,m in ipairs(inventory.Mappings)do assert(m.Key.KeyName==expected[i] and m.SettingBehavior==2)end
api:CloseInventory();assert(not active[inventory] and overlay.InputMapping==nil and overlay.InputMappingPriority==7)
assert(api:OpenInventory(overlay,sub) and api.contexts.inventory==inventory and constructed==10)
api:CloseInventory();overlay.InputMapping=object('external')
assert(not pcall(function()api:OpenInventory(overlay,sub)end))
assert(overlay.InputMapping==objects.external and not active[inventory])
assert(api:Owns(inventory) and api:Owns(api.contexts.gameplay) and not api:Owns(objects.external))
print('PASS persistent input: stable actions/rebinding, callback ownership, fixed 12-key inventory context reuse, close/restoration and external-owner refusal')

local removals=0
local originalRemove=sub.RemoveMappingContext
function sub:RemoveMappingContext(c)removals=removals+1;originalRemove(self,c)end
overlay.InputMapping=nil
assert(api:AttachInventory(overlay,sub));api:DeactivateInventory();api:DeactivateInventory()
assert(removals==0,'inactive S overlay must not issue repeated context removal')
assert(api:OpenInventory(overlay,sub));api:DeactivateInventory();api:DeactivateInventory()
assert(removals==1,'close removes an active assignment context once')
print('PASS inventory removal idempotence')
