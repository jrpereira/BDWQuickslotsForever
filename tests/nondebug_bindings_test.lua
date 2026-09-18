local file=assert(io.open("Scripts/main.lua","rb")); local source=file:read("*a"); file:close()
assert(loadfile("Scripts/main.lua"))
assert(not source:find("INPUT TRACE",1,true) and not source:find("INPUT SNAPSHOT",1,true))
assert(not source:find("input_diagnostics.lua",1,true))
local first=assert(source:find("local function bind_bridge_actions(",1,true))
local last=assert(source:find("local function gameplay_context_signature(",first,true))
local bindings,dispatches,logs={},{},{}
local bridge={}
local configured
local persistent={Configure=function(_,c) configured=c end,
 Bind=function(_,input,sub,defs,callback)
  for _,entry in ipairs(defs) do bindings[#bindings+1]={callback=callback(entry)} end
  return true
 end}
local state={generation=3,ready=true,helperHandles={}}
local config={HoldThresholdMs=200}
local defs={}
for _,group in ipairs({"Ability","Consumable"}) do for slot=1,4 do
  local field=group..slot; defs[#defs+1]={group=group,slot=slot,field=field}; config[field]=81; config[field.."Mode"]=slot%2
end end
local permitted=true
local env=setmetatable({Enhanced=state,Config=config,PersistentInput=persistent,VK_TO_FKEY={[81]="Q"},
  bridge_api=function() return bridge end,object_path=function(o) return o.path end,
  clear_bridge_bindings=function() error("unexpected cleanup") end,
  ExecuteInGameThread=function(fn) fn() end,action_input_allowed=function() return permitted end,
  trigger_ability=function(slot) dispatches[#dispatches+1]="Ability"..slot; return true end,
  trigger_consumable=function(slot) dispatches[#dispatches+1]="Consumable"..slot; return true end,
  log=function(s) logs[#logs+1]=s end}, {__index=_G})
local bind=assert(load(source:sub(first,last-1).."\nreturn bind_bridge_actions","nondebug-bindings","t",env))()
assert(bind({path="/pawn/input"},{path="/subsystem"},defs))
assert(configured==config and state.inputScope==persistent)
assert(#bindings==8 and #logs==0)
for i,b in ipairs(bindings) do
  b.callback({phase="Triggered"})
  assert(dispatches[i]==defs[i].field)
end
assert(#logs==0,"successful callbacks do not emit debug traces")
permitted=false; bindings[1].callback(); assert(#dispatches==8,"UI gate preserved")
permitted=true; state.ready=false; bindings[1].callback(); assert(#dispatches==8,"readiness gate preserved")
state.ready=true; state.generation=4; bindings[1].callback(); assert(#dispatches==8,"generation guard preserved")
print("PASS: eight persistent-action dispatch callbacks retain generation/readiness/UI guards; no debug diagnostics")
