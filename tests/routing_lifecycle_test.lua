local f=assert(io.open('Scripts/main.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local function enhanced_input_step()',1,true))
local b=assert(source:find('-- Runtime suppression is applied',a,true))
local function obj(n)return {name=n,valid=true}end
local sub,pi,input,pc,pawn=obj('sub'),obj('pi'),obj('input'),obj('pc'),obj('pawn')
local route='OW';local closes,setups,ensures=0,0,0;local closeOK=true
local state={ready=true,sub=sub,playerInput=pi,inputComponent=input,controller=pc,pawn=pawn,inputScope={},gameplayContextSignature=route}
local env=setmetatable({Config={Enabled=1},Enhanced=state,valid=function(o)return o and o.valid end,
 live_subsystem=function()return sub end,find_gameplay_stack=function()return pc,pawn,pi,input end,
 fullname=function(o)return o.name end,gameplay_context_signature=function()return route end,
 clear_bridge_bindings=function()closes=closes+1;return closeOK end,
 setup_enhanced_input=function()setups=setups+1;state.ready=true;state.sub=sub;state.playerInput=pi;state.inputComponent=input;state.controller=pc;state.pawn=pawn;return true end,
 PersistentInput={EnsureGameplay=function()ensures=ensures+1 end},log=function()end}, {__index=_G})
local step=assert(load(source:sub(a,b-1)..'\nreturn enhanced_input_step','routing-lifecycle','t',env))()
assert(step());route='RTCombat';assert(step());route='OW';assert(step())
assert(closes==0 and setups==0 and ensures==3,'routing alone preserves input subscriptions')
input=obj('new component');assert(step() and closes==1 and setups==1)
pawn=obj('new pawn');assert(step() and closes==2 and setups==2)
pc=obj('new controller');closeOK=false;assert(not step() and setups==2,'failed close cannot claim ready for new owner')
closeOK=true;assert(step() and setups==3)
state.ready=false;assert(step() and setups==4,'configuration invalidation still reconfigures')
print('PASS routing: OW/combat retains subscriptions, missing contexts repair, owner/component changes rebind, failed close retry and config rebind')
