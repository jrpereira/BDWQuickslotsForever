local function read(path)
  local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s
end
local source=read('Scripts/main.lua')
local metadata=read('mod_settings.ini')
assert(not metadata:match('\nDecoration[%w]*%s*='),'schema must use canonical Deco metadata')
assert(not metadata:find('DecoHeader',1,true) and not metadata:find('DecoFont',1,true),'level controls styling and header promotion')
local enabled=assert(metadata:match('%[Setting%.Enabled%](.-)%[Setting%.'))
assert(enabled:find('DecoLevel = 1',1,true),'master toggle replaces default header through level1')
local tabs,keys=0,0
for value in metadata:gmatch('DecoType%s*=%s*([^\r\n]+)') do
  assert(value=='tab' or value=='keybind','unsupported canonical DecoType')
  if value=='tab' then tabs=tabs+1 else keys=keys+1 end
end
assert(tabs==3 and keys==19,'three tab controls and Direct/Selective inputs remain decorated')
local parents={}
for value in metadata:gmatch('DecoParent%s*=%s*([^\r\n]+)') do parents[value]=(parents[value] or 0)+1 end
local parentKinds=0;for _ in pairs(parents)do parentKinds=parentKinds+1 end
assert(parentKinds==2 and parents['Interaction: Direct']==2 and parents['Interaction: Selective']==1,
  'persistent interaction headings must contain the existing subgroups')
for value in metadata:gmatch('DecoLevel%s*=%s*([^\r\n]+)') do
  local n=tonumber(value);assert(n and n%1==0 and n>=0 and n<=6,'font level must be numeric 0..6')
end

local expected={}
for _,group in ipairs({'Ability','Consumable'})do
  for slot=1,4 do expected[#expected+1]=group..slot;expected[#expected+1]=group..slot..'Mode' end
end
local groups={['General Settings']=true,['More Options']=true,['Primary Visuals']=true,Secondary=true,
  Selective=true,Abilities=true,Consumables=true}
for group in metadata:gmatch('Group = ([^\r\n]+)')do assert(groups[group],'unexpected menu section: '..group)end
assert(not metadata:find('[Setting.SwapAbilitiesWithConsumables]',1,true),'PrimaryWheel is the sole public selection')
local categoryOrder={};for category in metadata:gmatch('%[Category%.([^%]]+)%]')do categoryOrder[#categoryOrder+1]=category end
assert(categoryOrder[#categoryOrder-2]=='More Options' and categoryOrder[#categoryOrder-1]=='Primary Visuals'
  and categoryOrder[#categoryOrder]=='Secondary','visual settings belong at the bottom in role order')
local primaryX=assert(metadata:find('[Setting.PrimaryX]',1,true))
local primaryY=assert(metadata:find('[Setting.PrimaryY]',1,true))
local secondaryX=assert(metadata:find('[Setting.SecondaryX]',1,true))
local secondaryY=assert(metadata:find('[Setting.SecondaryY]',1,true))
assert(primaryX<primaryY and primaryY<secondaryX and secondaryX<secondaryY,
  'position controls must present Primary before Secondary')
for _,id in ipairs({'PrimarySize','PrimaryOpacity','SecondarySize','SecondaryOpacity'})do
  assert(metadata:find('[Setting.'..id..']',1,true),'missing visual setting '..id)
end
local defaults=read('distribution/config.ini'):match('%[Bindings%]%s*(.-)%[Presets%]')
local keys={};for k in defaults:gmatch('([%w]+)=')do keys[k]=true end
for _,k in ipairs(expected)do assert(keys[k],'missing default '..k);keys[k]=nil end
for _,k in ipairs({'SecondaryWheelKey','SecondaryWheelMode','PrimaryWheelKey'})do assert(keys[k]);keys[k]=nil end
assert(next(keys)==nil,'bindings defaults contain a non-Quickslot control')

-- Quickslot initialization must succeed with only its own persistent input scope.
-- The subsystem intentionally exposes no context-cloning/mapping methods.
local sub,pc,pawn,pi,input={},{},{},{},{}
local state={ready=false};local definitions,cleanup=0,0
local e=setmetatable({PersistentInput={Validate=function()return true end},Enhanced=state,Config={HoldThresholdMs=200,InteractionMode=0},
  BINDING_GROUPS={'Ability','Consumable'},valid=function(o)return o~=nil end,
  live_subsystem=function()return sub end,find_gameplay_stack=function()return pc,pawn,pi,input end,
  bridge_api=function()return {} end,clear_bridge_bindings=function()return true end,
  object_path=function()return '/player/input' end,
  bind_bridge_actions=function(component,owner,defs)
    assert(component==input and owner==sub and #defs==8)
    for i,d in ipairs(defs)do assert(d.field==expected[2*i-1])end
    definitions=#defs;state.actions=defs;return true
  end,
  update_native_action_gates=function()cleanup=cleanup+1 end,
  gameplay_context_signature=function()return 'OW' end,
  sync_blocking_widgets_once=function()end,log=function()end}, {__index=_G})
local a=assert(source:find('local function setup_enhanced_input()',1,true))
local b=assert(source:find('local DisabledContextCleaned=',a,true))
local setup=assert(load(source:sub(a,b-1)..'\nreturn setup_enhanced_input','quickslot-setup','t',e))()
assert(setup() and state.ready and definitions==8 and cleanup==1)
assert(setup() and cleanup==1,'ready setup should be idempotent')
print('PASS Quickslot-only setup, eight controls, menu scope')
