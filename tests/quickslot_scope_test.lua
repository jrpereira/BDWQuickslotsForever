local function read(path)
  local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s
end
local source=read('Scripts/main.lua')
local metadata=read('mod_settings.ini')
local expected={}
for _,group in ipairs({'Ability','Consumable'})do
  for slot=1,4 do expected[#expected+1]=group..slot;expected[#expected+1]=group..slot..'Mode' end
end
local targets=assert(metadata:match('MappedPresetTargets = ([^\r\n]+)'))
assert(targets==table.concat(expected,'|'),'presets must target only the eight Quickslots')
local presetCount=0
for preset in assert(metadata:match('MappedPresetValues = ([^\r\n]+)')):gmatch('[^;]+')do
  local id,values=preset:match('^(%d+):(.*)$');assert(id)
  local n=0;for value in values:gmatch('[^|]+')do n=n+1;assert(tonumber(value))end
  assert(n==#expected,'each preset must supply one value for every target');presetCount=presetCount+1
end
assert(presetCount==3)
local groups={['General Settings']=true,Wheels=true,['Control Overrides']=true,Abilities=true,Consumables=true}
for group in metadata:gmatch('Group = ([^\r\n]+)')do assert(groups[group],'unexpected menu section: '..group)end
local defaults=read('distribution/config.ini'):match('%[Bindings%]%s*(.-)%[Presets%]')
local keys={};for k in defaults:gmatch('([%w]+)=')do keys[k]=true end
for _,k in ipairs(expected)do assert(keys[k],'missing default '..k);keys[k]=nil end
assert(next(keys)==nil,'bindings defaults contain a non-Quickslot control')

-- Quickslot initialization must succeed with only its own persistent input scope.
-- The subsystem intentionally exposes no context-cloning/mapping methods.
local sub,pc,pawn,pi,input={},{},{},{},{}
local state={ready=false};local definitions,cleanup=0,0
local e=setmetatable({PersistentInput={Validate=function()return true end},Enhanced=state,Config={HoldThresholdMs=200},
  BINDING_GROUPS={'Ability','Consumable'},valid=function(o)return o~=nil end,
  live_subsystem=function()return sub end,find_gameplay_stack=function()return pc,pawn,pi,input end,
  bridge_api=function()return {} end,clear_bridge_bindings=function()return true end,
  object_path=function()return '/player/input' end,
  bind_bridge_actions=function(component,owner,defs)
    assert(component==input and owner==sub and #defs==8)
    for i,d in ipairs(defs)do assert(d.field==expected[2*i-1])end
    definitions=#defs;state.actions=defs;return true
  end,
  remove_native_conflicts=function()cleanup=cleanup+1 end,
  gameplay_context_signature=function()return 'OW' end,
  sync_blocking_widgets_once=function()end,log=function()end}, {__index=_G})
local a=assert(source:find('local function setup_enhanced_input()',1,true))
local b=assert(source:find('local DisabledContextCleaned=',a,true))
local setup=assert(load(source:sub(a,b-1)..'\nreturn setup_enhanced_input','quickslot-setup','t',e))()
assert(setup() and state.ready and definitions==8 and cleanup==1)
assert(setup() and cleanup==1,'ready setup should be idempotent')
print('PASS Quickslot-only setup, eight controls, three complete presets and menu scope')
