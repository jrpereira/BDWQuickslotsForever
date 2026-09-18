local f=assert(io.open('Scripts/main.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local SuppressionNeedsSnapshot=true',1,true))
local b=assert(source:find('-- Dawnwalker keeps gameplay',a,true))
local context={Mappings={{Action='target',Key={KeyName='One'},SettingBehavior=0}}}
local pi={AppliedInputContexts={[context]=1}}
local snapshots,visits,rebuilds=0,0,0
local suppression=dofile('Scripts/runtime_suppression.lua')({load=function()return '' end,save=function()end,
 valid=function(o)return o~=nil end,path=function(o)return o==context and '/Game/context' or 'target' end,
 resolve=function()return context end,owned=function()return false end,target=function()return true end,
 name=function(n)return n end,key=function(m)return m.Key.KeyName end,
 each=function(t,fn)visits=visits+1;for i,v in ipairs(t)do fn(i,v)end end,
 rebuild=function()rebuilds=rebuilds+1 end})
local env=setmetatable({Config={Enabled=1,RemoveDefinedActionBindings=0},Suppression=suppression,
 Enhanced={playerInput=pi},valid=function(o)return o~=nil end,safe=function(o,k)return o[k]end,unwrap=function(o)return o end,
 each_container=function(t,fn)snapshots=snapshots+1;for k in pairs(t)do fn(k)end;return true end}, {__index=_G})
local run,snapshot=assert(load(source:sub(a,b-1)..'\nreturn remove_native_conflicts,RequestSuppressionSnapshot','suppression-events','t',env))()
assert(run());assert(context.Mappings[1].Key.KeyName=='None','legacy Off must not prevent startup suppression');for i=1,1000 do assert(run())end
assert(snapshots==1 and visits==1 and rebuilds==1,'unchanged cleanup performs no mapping or active-context scans')
context.Mappings[1].Key.KeyName='Two';context.Mappings[1].SettingBehavior=0
snapshot(true);assert(run());assert(snapshots==2 and visits==2 and rebuilds==2,'Controls remap invalidates mapping cache')
suppression:Invalidate(context);assert(suppression:Apply({context}));assert(visits==3 and snapshots==2,'incoming context only scans that context')
env.Config.Enabled=0;assert(run());assert(context.Mappings[1].Key.KeyName=='Two' and rebuilds==3,'disable restores the latest native Controls choice')
env.Config.Enabled=1;assert(run());assert(snapshots==3 and rebuilds==4,'re-enable rescans restored context')
print('PASS scoped suppression: stable cleanup is scan-free, Controls/incoming-context invalidation and master restoration/re-enable')

-- Exercise the real pre-activation hook with an old config that disabled suppression.
local first=assert(source:find('  local okSuppressHook,suppressHookError=',1,true))
local last=assert(source:find("  for _,name in ipairs({'AddMappingContext'",first,true))
local before
local hookEnv=setmetatable({Config={Enabled=1,RemoveDefinedActionBindings=0},Suppression=suppression,
 RegisterHook=function(_,pre)before=pre end,unwrap=function(o)return o end,
 valid=function(o)return o~=nil end,object_path=function()return '/Game/context' end,
 SuppressionDirty={},log=function(message)error(message)end},{__index=_G})
assert(load(source:sub(first,last-1),'actual-pre-suppression','t',hookEnv))()
context.Mappings[1].Key.KeyName='Three';context.Mappings[1].SettingBehavior=0
before(nil,context)
assert(context.Mappings[1].Key.KeyName=='None','incoming native context is suppressed despite legacy Off')
hookEnv.Config.Enabled=0
context.Mappings[1].Key.KeyName='Four';context.Mappings[1].SettingBehavior=0
before(nil,context)
assert(context.Mappings[1].Key.KeyName=='Four','master disable still leaves native controls alone')
print('PASS automatic suppression: startup and incoming-context hook ignore legacy Off; master disable still applies')
