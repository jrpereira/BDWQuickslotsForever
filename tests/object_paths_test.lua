local factory=dofile('Scripts/object_paths.lua')
local a={path='/world/a',valid=true}
local objects={a};local live={[a.path]=a};local scans,visits=0,0
local env={find=function()scans=scans+1;return objects end,valid=function(o)return o and o.valid end,
 path=function(o)return o.path end,resolve=function(p)return live[p]end}
local cache=factory(env,'Radial')
local function visit()assert(cache:Visit(function(o)assert(o.valid);visits=visits+1 end))end
for i=1,1000 do visit()end
assert(scans==1 and visits==1000,'stable visits never trigger arbitrary rediscovery')
a.valid=false;visit();assert(visits==1000 and scans==1,'invalid entry pruned without global scan')
local b={path='/world/b',valid=true};live[b.path]=b;objects={b}
cache:Add(b);visit();assert(visits==1001 and scans==1,'creation directly adds known object')
cache:Invalidate();visit();assert(scans==2 and visits==1002,'lifecycle invalidates discovery')
local failures=0
local failing=factory({find=function()failures=failures+1;if failures==1 then error('unavailable')end;return {}end,
 valid=env.valid,path=env.path,resolve=env.resolve},'Radial')
assert(not failing:Visit(function()end));assert(failing:Visit(function()end));assert(failures==2)
local template={path='/Game/Blueprint.C:WidgetTree.Radial',valid=true}
local instance={path='/Engine/Transient.HUD.Radial',valid=true};live[instance.path]=instance
local count=0
local onlyLive=factory({find=function()return {template,instance}end,valid=env.valid,path=env.path,resolve=env.resolve,
 live=function(o)return o.path:find('/Engine/Transient',1,true)~=nil end},'Radial')
onlyLive:Add(template);onlyLive:Visit(function()count=count+1 end)
assert(count==1)
print('PASS event-only discovery: 1000 visits one scan, direct creation add, invalidation, dead pruning, errors and template exclusion')
