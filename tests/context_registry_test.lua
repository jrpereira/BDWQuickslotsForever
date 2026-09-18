local factory=assert(loadfile("Scripts/context_registry.lua"))()
assert(loadfile("Scripts/main.lua"))
local key="QuickslotsForever.DrawContextPath.v1"
local legacyA,legacyB="QuickslotsForever.EnhancedContext","QuickslotsForever.DrawContext"
local owner={path="/live/subsystem",valid=true}
local context={path="/live/subsystem.DrawContext_123",valid=true}
local shared={[legacyA]={stale=true},[legacyB]={stale=true}}
local objects={[context.path]=context}
local resolved,removed={},{}
local failRemove=false
local registry=factory({
  get_shared=function(name)
    assert(name~=legacyA and name~=legacyB,"legacy shared UObject conversion attempted before IsValid")
    return shared[name]
  end,
  set_shared=function(name,value)
    assert(value==nil or type(value)=="string","shared UObject publication must never return")
    shared[name]=value
  end,
  path=function(o) return o and o.valid and o.path or nil end,
  valid=function(o) return o and o.valid end,
  resolve=function(path) resolved[#resolved+1]=path; return objects[path] end,
  remove=function(sub,obj)
    assert(not failRemove,"simulated remove failure")
    removed[#removed+1]={sub=sub,object=obj}
  end,
})
registry:ForgetLegacy()
assert(shared[legacyA]==nil and shared[legacyB]==nil,"upgrade clears legacy values without fetching")
registry:Remember(context,owner)
assert(shared[key]==context.path)
assert(registry:Clear(owner) and #removed==1 and removed[1].object==context and shared[key]==nil,"same-world cleanup")
registry:Remember(context,owner)
objects[context.path]=nil -- GC/world teardown: no object exists at the saved path.
assert(registry:Clear(owner) and #removed==1 and shared[key]==nil,"dead context causes no object dereference")
objects[context.path]=context
registry:Remember(context,owner)
local resolvedBefore=#resolved
assert(registry:Clear({path="/new/subsystem",valid=true}))
assert(#resolved==resolvedBefore and #removed==1 and shared[key]==nil,"new owner does not touch old lifetime")
registry:Remember(context,owner)
assert(not registry:Clear({valid=false}) and shared[key]==context.path,"unavailable target defers cleanup")
failRemove=true
assert(not pcall(function() registry:Clear(owner) end) and shared[key]==context.path,"failed removal remains retryable")
failRemove=false
assert(registry:Clear(owner) and #removed==2)
assert(not pcall(function() registry:Remember({path="/live/subsystemOther.Context",valid=true},owner) end),"ownership prefix requires dot boundary")
-- Hot reload of v0.3.31 preserves the string registry, not a UObject wrapper.
registry:Remember(context,owner); registry:ForgetLegacy()
assert(shared[key]==context.path and registry:Clear(owner))
local source=assert(io.open("Scripts/main.lua","rb")); local main=source:read("*a"); source:close()
assert(not main:find('GetSharedVariable("QuickslotsForever.DrawContext")',1,true))
assert(not main:find('SetSharedVariable("QuickslotsForever.DrawContext",drawContext)',1,true))
print("PASS: context path registry, no legacy UObject reads/writes, dead-world cleanup, owner replacement, retry and reload")
