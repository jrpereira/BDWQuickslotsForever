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
