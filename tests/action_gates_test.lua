local function object(class,path)
  return {class=class,path=path,valid=true,Triggers={}}
end
local dummy=object('InputAction','/Engine/Transient.IMC_QuickslotsForever:IA_QSF_NativeActionGate')
local a=object('InputAction','/Game/A.IA_A')
local b=object('InputAction','/Game/B.IA_B')
local nativeA=object('InputTriggerPressed','/Game/A.IA_A:Pressed')
local nativeB=object('InputTriggerReleased','/Game/B.IA_B:Released')
a.Triggers={nativeA};b.Triggers={nativeB}
local actions={a,b}
local wanted={['/Game/A.IA_A']=true,['/Game/B.IA_B']=true}
local rebuilds={}
local created={}
local function path(o)return o and o.path end
local api=dofile('Scripts/action_gates.lua')({
  valid=function(o)return o and o.valid end,path=path,unwrap=function(o)return o end,
  same=function(x,y)return path(x)==path(y) end,
  each=function(c,fn)for i,v in ipairs(c or {})do fn(i,v)end end,
  actions=function()return actions end,target=function(o)return wanted[path(o)]==true end,
  retain_dummy=function()return dummy end,
  construct=function(owner,name)
    local t=object('InputTriggerChordAction',owner.path..':'..name)
    created[#created+1]=t
    return t
  end,
  chord=function(t)return t.ChordAction end,set_chord=function(t,v)t.ChordAction=v end,
  set_triggers=function(o,v)o.Triggers=v end,
  rebuild=function(changed)rebuilds[#rebuilds+1]=changed;return true end,
})
local ok,n=api:Update();assert(ok and n==2 and #created==2 and #rebuilds==1)
assert(a.Triggers[1]==nativeA and a.Triggers[2]==created[1] and created[1].ChordAction==dummy)
assert(b.Triggers[1]==nativeB and b.Triggers[2]==created[2] and created[2].ChordAction==dummy)
assert(created[1]~=created[2],'each action owns a distinct gate')
ok,n=api:Update();assert(ok and n==0 and #created==2 and #rebuilds==1,'repeat update must be inert')

-- Foreign trigger insertion and native ordering survive selective removal.
local foreign=object('InputTriggerChordAction','/Game/A.IA_A:ForeignGate')
table.insert(a.Triggers,2,foreign)
wanted[a.path]=false
ok,n=api:Update();assert(ok and n==1 and #a.Triggers==2)
assert(a.Triggers[1]==nativeA and a.Triggers[2]==foreign,'only the owned gate is removed')
assert(#b.Triggers==2 and b.Triggers[2]==created[2])

-- A Lua reload recovers the deterministically named gate instead of appending one.
local reloaded=dofile('Scripts/action_gates.lua')({
  valid=function(o)return o and o.valid end,path=path,unwrap=function(o)return o end,
  same=function(x,y)return path(x)==path(y) end,
  each=function(c,fn)for i,v in ipairs(c or {})do fn(i,v)end end,
  actions=function()return actions end,target=function(o)return wanted[path(o)]==true end,
  retain_dummy=function()return dummy end,
  construct=function()error('reload duplicated an owned gate')end,
  chord=function(t)return t.ChordAction end,set_chord=function(t,v)t.ChordAction=v end,
  set_triggers=function(o,v)o.Triggers=v end,rebuild=function(changed)assert(#changed==1 and changed[1]==b);return true end,
})
assert(reloaded:Update())

ok,n=api:RestoreAll();assert(ok and n==1 and #b.Triggers==1 and b.Triggers[1]==nativeB)
assert(#a.Triggers==2 and a.Triggers[1]==nativeA and a.Triggers[2]==foreign)

-- A failed rebuild remains pending even though the object mutation is already complete.
wanted[a.path]=true
local fail=true;local attempts=0
local retry=dofile('Scripts/action_gates.lua')({
  valid=function(o)return o and o.valid end,path=path,unwrap=function(o)return o end,
  same=function(x,y)return path(x)==path(y) end,
  each=function(c,fn)for i,v in ipairs(c or {})do fn(i,v)end end,
  actions=function()return {a}end,target=function()return true end,retain_dummy=function()return dummy end,
  construct=function(owner,name)return object('InputTriggerChordAction',owner.path..':'..name)end,
  chord=function(t)return t.ChordAction end,set_chord=function(t,v)t.ChordAction=v end,
  set_triggers=function(o,v)o.Triggers=v end,rebuild=function()attempts=attempts+1;if fail then fail=false;return false end;return true end,
})
assert(not pcall(function()retry:Update()end));assert(#a.Triggers==3)
assert(retry:Update() and attempts==2 and #a.Triggers==3,'failed rebuild must retry without duplicating the gate')
print('PASS action gates: distinct ownership, idempotence, reload recovery, foreign preservation and exact restoration')
