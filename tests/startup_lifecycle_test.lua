-- Reproduce a HUD arriving before the player, followed by late input readiness.
local jobs,counts,delays={},{},{}
local ready=false
local factory=dofile('Scripts/event_work.lua')
local work
work=factory({attempts=2,enabled=function()return true end,log=function()end,
 queue=function(fn)jobs[#jobs+1]=fn end,
 delay=function(ms,fn)delays[#delays+1]=fn end,
 run=function(name)
  counts[name]=(counts[name] or 0)+1
  if name=='input' then
   if ready then work:AfterReady('hud');work:AfterReady('inventory') end
   return ready
  end
  if name=='hud' or name=='inventory' then return ready end
  return true
 end})
local function tick() local fn=table.remove(jobs,1) or table.remove(delays,1);if fn then fn()end end
work:Request('input');work:Request('hud');work:Request('inventory')
for i=1,8 do tick()end
assert(counts.hud==2 and counts.inventory==2 and counts.input==2)
ready=true;work:Request('input');tick();tick()
assert(counts.hud==3 and counts.inventory==3,'late input readiness must revive dependent work')
for i=1,100 do tick()end
assert(counts.hud==3 and counts.input==3,'dependency handoff must settle without polling')

-- Native actions may not be loaded when the S overlay first activates.
local available=false;local mutations=0;local objects={}
local function retain(_,name)
 local c={name=name,Mappings={}}
 function c:UnmapAll()self.Mappings={};mutations=mutations+1 end
 function c:MapKey(a,k)self.Mappings[#self.Mappings+1]={Action=a,Key=k}end
 objects[name]=c;return c
end
local api=dofile('Scripts/persistent_input.lua')({
 valid=function(v)return v~=nil end,native_action=function(d)if available then return d end end,
 retain=retain,name=function(s)return s end,each=function(t,fn)for i,m in ipairs(t)do fn(i,m)end end})
assert(not api:PrepareInventory() and mutations==0,'missing actions must not partially mutate context')
available=true;assert(api:PrepareInventory() and #api.contexts.inventory.Mappings==12)
assert(api:PrepareInventory() and mutations==1,'repeat readiness must not recreate context mappings')

-- A Lua reload retains the native action needed to restore existing widgets.
local native={name='native'};local action={name='mod'}
local widget={name='widget',EnhancedInputAction=native}
function widget:SetEnhancedInputAction(a)self.EnhancedInputAction=a end
local objectsByName={widget=widget,native=native,mod=action};local journal=''
local env={valid=function(o)return o~=nil end,path=function(o)return o and o.name end,
 same=function(a,b)return a==b end,resolve=function(p)return objectsByName[p]end,
 load=function()return journal end,save=function(s)journal=s end}
local indicator=dofile('Scripts/action_indicators.lua')
local first=indicator(env);assert(first:Set(widget,action))
local reloaded=indicator(env);assert(reloaded:Set(widget,action))
assert(reloaded:RestoreAll() and widget.EnhancedInputAction==native and journal=='')
print('PASS startup lifecycle: late player after exhausted HUD retries, inventory actions missing, bounded settle, Lua-reload indicator restoration')

local retainedContext={};local retainedSub={}
local retainedOverlay={InputMapping=retainedContext,InputMappingPriority=10002}
local removed=0
function retainedSub:RemoveMappingContext(c)assert(c==retainedContext);removed=removed+1 end
local live={sub=retainedSub,overlay=retainedOverlay,context=retainedContext}
local ownership='overlay\t-3\tsub\tcontext'
local reloadedInput=dofile('Scripts/persistent_input.lua')({
 valid=function(o)return o~=nil end,resolve=function(p)return live[p]end,same=function(a,b)return a==b end,
 load_inventory=function()return ownership end,save_inventory=function(v)ownership=v end})
reloadedInput:CloseInventory()
assert(removed==1 and retainedOverlay.InputMapping==nil and retainedOverlay.InputMappingPriority==-3 and ownership=='')
print('PASS inventory Lua reload: adopt old ownership and restore original negative priority when overlay closes')
