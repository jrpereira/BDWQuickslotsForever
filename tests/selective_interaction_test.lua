local objects,active,handlers={},false,{}
local function object(name)
  local o={name=name,valid=true,Mappings={},Triggers={}}
  function o:UnmapAll()self.Mappings={}end
  function o:MapKey(action,key)self.Mappings[#self.Mappings+1]={Action=action,Key=key}end
  objects[name]=o;return o
end
local sub=object('sub')
function sub:AddMappingContext()active=true end
function sub:RemoveMappingContext()active=false end
local healthy=true
local bridge
bridge={
  GetCapabilities=function()return {target_delivery_faults=true}end,
  OpenInputComponent=function()return 7 end,
  CloseInputComponent=function()active=false;return true end,
  SetTargetDeliveryFaultHandler=function(_,fn)bridge.fault=fn;return true end,
  IsTargetDeliveryValid=function(target)return healthy and target==7 end,
  BindAction=function(_,path,phase,fn)handlers[path..':'..phase]=fn;return 1 end,
}
local api=dofile('Scripts/persistent_input.lua')({
  valid=function(o)return o and o.valid end,path=function(o)return o.name end,
  resolve=function(path)return objects[path]end,same=function(a,b)return a==b end,
  name=function(v)return v end,key=function(v)return v end,
  retain=function(_,name)return objects[name]or object(name)end,
  each=function(t,fn)for i,v in ipairs(t)do fn(i,v)end end,
  bridge=function()return bridge end,initialize_identity=function()end,
  trigger=function(action,mode,threshold)action.mode=mode;action.threshold=threshold end,
})
local route=dofile('Scripts/wheel_routing.lua')()
local config={InteractionMode=1,PrimaryWheel=0,SecondaryWheelKey='Alt',SecondaryWheelMode=2,
  PrimaryWheelKey=0,HoldThresholdMs=999}
api:Configure(config);route:Configure(config)
assert(#api.contexts.gameplay.Mappings==1)
assert(api.actions.SecondaryWheelKey.mode==2,'Secondary Hold must use Hold Sustained')
local defs={{field='SecondaryWheelKey',select='secondary',mode=2,momentary=true}}
assert(api:Bind(object('input'),sub,defs,function(binding,phase)
  return function()route:Phase(binding,phase)end
end))
local path=api.actions.SecondaryWheelKey.name
assert(handlers[path..':Started'] and handlers[path..':Completed'] and handlers[path..':Canceled'])
assert(not handlers[path..':Triggered'],'Hold Sustained must not wait for a trigger threshold')
handlers[path..':Started']();assert(route.active=='Ability')
handlers[path..':Completed']();assert(route.active=='Consumable')
handlers[path..':Started']();handlers[path..':Canceled']();assert(route.active=='Consumable')
healthy=false;assert(not api:IsDeliveryValid(7));healthy=true;assert(api:Close())

config.SecondaryWheelMode=0;config.SecondaryWheelKey='F2';config.PrimaryWheelKey='F1'
api:Configure(config);route:Configure(config);handlers={}
assert(#api.contexts.gameplay.Mappings==2)
local tapDefs={{field='SecondaryWheelKey',select='secondary',mode=0},
  {field='PrimaryWheelKey',select='primary',mode=0}}
assert(api:Bind(object('input2'),sub,tapDefs,function(binding,phase)
  return function()route:Phase(binding,phase)end
end))
handlers[api.actions.SecondaryWheelKey.name..':Triggered']();assert(route.active=='Ability')
handlers[api.actions.PrimaryWheelKey.name..':Triggered']();assert(route.active=='Consumable')
local mappings=api.contexts.gameplay.Mappings
config.PrimaryWheelKey='F2'
assert(not pcall(function()api:Configure(config)end))
assert(api.contexts.gameplay.Mappings==mappings,'invalid Tap plan must not mutate active mappings')
print('PASS Selective Tap Trigger and immediate Hold Sustained lifecycle')
