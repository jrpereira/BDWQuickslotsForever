local left={path='Left',target=true};local top={path='Top',target=true};local other={path='Other'}
local function map(a,key,behavior)return {Action=a,Key={KeyName=key},SettingBehavior=behavior or 0}end
local native={path='/native',Mappings={map(left,'None'),map(left,'One'),map(top,'Two'),map(other,'Q')}}
local owned={path='/owned',owned=true,Mappings={map(left,'One')}}
local objects={['/native']=native,['/owned']=owned};local saved='';local rebuilds=0;local fail=false
local env={valid=function(o)return o~=nil end,path=function(o)return o.path end,
 resolve=function(p)return objects[p]end,name=function(n)return n end,target=function(a)return a.target end,
 owned=function(c)return c.owned end,key=function(m)return m.Key.KeyName end,
 each=function(t,fn)for i,m in ipairs(t)do fn(i,m)end end,
 load=function()return saved end,save=function(s)saved=s end,
 rebuild=function()if fail then error('injected')end;rebuilds=rebuilds+1 end}
local factory=dofile('Scripts/runtime_suppression.lua');local api=factory(env)
assert(api:Apply({native,owned}) and rebuilds==1)
for i=1,3 do assert(native.Mappings[i].Key.KeyName=='None' and native.Mappings[i].SettingBehavior==2)end
assert(native.Mappings[4].Key.KeyName=='Q' and owned.Mappings[1].Key.KeyName=='One')
api:Apply({native,owned});assert(rebuilds==1,'no rebuild loop')
api=factory(env) -- reload retains the true original fields
fail=true;assert(not pcall(function()api:Restore()end) and saved~='')
fail=false;assert(api:Restore() and saved=='' and rebuilds==2)
assert(native.Mappings[1].Key.KeyName=='None' and native.Mappings[1].SettingBehavior==0)
assert(native.Mappings[2].Key.KeyName=='One' and native.Mappings[3].Key.KeyName=='Two')
api:Apply({native});native.Mappings[2].Key.KeyName='External';native.Mappings[2].SettingBehavior=1
api:Restore();assert(native.Mappings[2].Key.KeyName=='External' and native.Mappings[2].SettingBehavior==1)
print('PASS suppression: None inheritance, all mappings/action, owned exclusions, one rebuild/context, reload journal, failure retry, restoration and external changes')

-- Failed apply rebuild stays dirty even though source fields already changed.
api=factory(env);fail=true
assert(not pcall(function()api:Apply({native})end))
local before=rebuilds
assert(not pcall(function()api:Apply({native})end),'second failed rebuild cannot report success')
fail=false;assert(api:Apply({}) and rebuilds==before+1,'retry pending rebuild without rescanning contexts')
fail=true;assert(not pcall(function()api:Restore()end) and saved~='')
fail=false;assert(api:Restore() and saved=='' and rebuilds==before+2,'restoration failure remains pending')
-- Reload after failed Apply must not lose rebuild obligation.
fail=true;assert(not pcall(function()api:Apply({native})end))
api=factory(env);fail=false;before=rebuilds
assert(api:Apply({native}) and rebuilds==before+1)
assert(api:Restore())
print('PASS suppression rebuild obligations survive failed Apply, repeated failure, failed Restore and Lua reload')

-- Native edits become the restoration baseline; row insertion/reordering does
-- not bind a saved key to the wrong action or to a different trigger variant.
native.Mappings={map(left,'One'),map(top,'Two')}
api=factory(env);api:Apply({native})
native.Mappings[1].Key.KeyName='Three';native.Mappings[1].SettingBehavior=1
api:Invalidate(native);api:Apply({native});api=factory(env)
table.insert(native.Mappings,1,map(other,'SpaceBar'))
native.Mappings[2],native.Mappings[3]=native.Mappings[3],native.Mappings[2]
assert(api:Restore())
assert(native.Mappings[1].Key.KeyName=='SpaceBar')
assert(native.Mappings[2].Key.KeyName=='Two' and native.Mappings[3].Key.KeyName=='Three')
assert(native.Mappings[3].SettingBehavior==1)
env.signature=function(m)return m.variant or ''end
native.Mappings={map(left,'Keyboard'),map(left,'Gamepad'),map(top,'Removed')}
native.Mappings[1].variant='tap';native.Mappings[2].variant='hold'
api=factory(env);api:Apply({native})
native.Mappings[1],native.Mappings[2]=native.Mappings[2],native.Mappings[1]
table.remove(native.Mappings,3)
table.insert(native.Mappings,map(other,'External'))
api:Invalidate(native);api:Apply({native});api=factory(env)
assert(api:Restore() and saved=='')
assert(native.Mappings[1].Key.KeyName=='Gamepad' and native.Mappings[2].Key.KeyName=='Keyboard')
assert(native.Mappings[3].Key.KeyName=='External')
-- An external replacement must not inherit the deleted action's saved key.
native.Mappings={map(left,'One')};api:Apply({native})
native.Mappings[1]=map(other,'Replacement')
assert(api:Restore() and native.Mappings[1].Key.KeyName=='Replacement' and saved=='')
-- Multiple equivalent rows remain separate after an unrelated insertion.
native.Mappings={map(left,'One'),map(left,'Two')};api:Apply({native})
table.insert(native.Mappings,1,map(other,'Q'));assert(api:Restore())
local restoredKeys={[native.Mappings[2].Key.KeyName]=true,[native.Mappings[3].Key.KeyName]=true}
assert(restoredKeys.One and restoredKeys.Two)
print('PASS suppression reconciliation: fresh native keys, insert/reorder/delete, trigger variants, duplicate actions and reload')
