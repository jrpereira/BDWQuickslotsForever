local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local source=read('Scripts/main.lua')
local a=assert(source:find('local function parse_ini(',1,true))
local b=assert(source:find('local LastConfigText=',a,true))
local loadconfig,keys=assert(load(source:sub(a,b-1)..'\nreturn load_config,VK_TO_FKEY','config','t',setmetatable({
 readall=function()return ''end,trim=function(s)return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$',''))end},{__index=_G})))()
local legacy=loadconfig('[General]\nHoldThresholdMs=375')
assert(legacy.PrimaryWheel==0 and legacy.HoldThresholdMs==375)
local split=loadconfig('[General]\nHoldThresholdMs=375\nPrimaryWheel=1\nPrimaryHoldThresholdMs=125\nSecondaryHoldThresholdMs=625')
assert(split.PrimaryWheel==1 and split.HoldThresholdMs==375 and split.PrimaryHoldThresholdMs==nil and split.SecondaryHoldThresholdMs==nil)
-- Renamed schema values win; legacy files are read without altering their text.
for _,primary in ipairs({0,1})do
 for _,swap in ipairs({0,1})do
  local text='[General]\nPrimaryWheel='..primary..'\nShowBothWheels=0\nShowWheels=2\nHoldThresholdMs=375\n[Position Modifiers]\nAbilitiesX=12\nAbilitiesY=34\nConsumablesX=56\nConsumablesY=-78\nSwapAbilitiesWithConsumables='..swap
  local c=loadconfig(text)
  assert(c.PrimaryWheel==primary and c.ShowBothWheels==1 and c.HoldThresholdMs==375)
  assert(c.PrimaryX==12 and c.PrimaryY==34 and c.SecondaryX==56 and c.SecondaryY==-78,'explicit primary ignores obsolete swap')
  assert(c.SwapAbilitiesWithConsumables==nil)
  c=loadconfig(text..'\n[More Options]\nPrimaryX=101\nPrimaryY=102\nSecondaryX=103\nSecondaryY=104')
  assert(c.PrimaryX==101 and c.PrimaryY==102 and c.SecondaryX==103 and c.SecondaryY==104)
 end
end
for _,swap in ipairs({0,1})do
 local c=loadconfig('[General]\nShowBothWheels=0\n[Position Modifiers]\nAbilitiesX=12\nAbilitiesY=34\nConsumablesX=56\nConsumablesY=-78\nSwapAbilitiesWithConsumables='..swap)
 assert(c.ShowBothWheels==0 and c.PrimaryWheel==0)
 assert(c.PrimaryY==(swap==0 and -78 or 34) and c.SecondaryY==(swap==0 and 34 or -78),'legacy actual wheel coordinates survive without inferring primary from swap')
end
assert(loadconfig('[General]\nShowBothWheels=1\nShowWheels=1').ShowBothWheels==0)
assert(loadconfig('[More Options]\nConsumablesX=91').SecondaryX==91,'intermediate edited schema X key remains readable')
print('PASS schema precedence, explicit primary, legacy coordinates and global threshold')
local input=dofile('Scripts/persistent_input.lua')({key=function(k)return keys[k]end})
local good=loadconfig(read('distribution/config.ini'));good.Ability1=20
assert(input:Validate(good)[1].key=='CapsLock')
local bad={};for k,v in pairs(good)do bad[k]=v end;bad.Ability1=7
local closed=0
local env=setmetatable({Config=good,LastConfigText='good',Enhanced={ready=true},
 PersistentInput=input,load_config=function()return bad end,clear_bridge_bindings=function()closed=closed+1 end}, {__index=_G})
a=assert(source:find('local function reconfigure_from_text(now)',1,true));b=assert(source:find('local notificationOk,notificationError=',a,true))
local apply=assert(load(source:sub(a,b-1)..'\nreturn reconfigure_from_text','apply','t',env))()
assert(not pcall(apply,'bad'))
assert(closed==0 and env.Config==good and env.Enhanced.ready and env.LastConfigText=='good' and env.PendingConfigBaseline==nil)
print('PASS invalid key plans preserve working input and committed state; CapsLock resolves')

local action={path='action',target=true};local other={path='other'}
local function row(key)return {Action=action,Key={KeyName=key},SettingBehavior=0}end
local function suppression(rows)
 local journal='';local c={path='context',Mappings=rows}
 local e={valid=function(o)return o~=nil end,path=function(o)return o.path end,
 resolve=function()return c end,name=function(n)return n end,target=function(o)return o.target end,
 owned=function()return false end,key=function(m)return m.Key.KeyName end,
 each=function(t,f)for i,m in ipairs(t)do f(i,m)end end,
 load=function()return journal end,save=function(s)journal=s end,rebuild=function()return true end}
 local factory=dofile('Scripts/runtime_suppression.lua')
 return factory(e),c,function()return factory(e)end,function()return journal end
end
for _,change in ipairs({'delete','mixed'}) do
 local api,c,_,saved=suppression({row('One'),row('Two')});api:Apply({c})
 if change=='delete' then table.remove(c.Mappings,1)
 else c.Mappings[1].Key={KeyName='Three'};c.Mappings[1].SettingBehavior=0;table.insert(c.Mappings,1,{Action=other,Key={KeyName='Q'},SettingBehavior=0}) end
 local before=saved();api:Invalidate(c)
 local ok,why=pcall(function()api:Apply({c})end)
 assert(not ok and tostring(why):find('Ambiguous suppressed mappings',1,true) and saved()==before)
 assert(not pcall(function()api:Restore()end) and saved()==before)
 -- Authoritative native reset supplies actual remaining bindings and resolves it.
 c.Mappings={row('Two')};api:Invalidate(c);api:Apply({c});api:Restore()
 assert(c.Mappings[1].Key.KeyName=='Two')
end
-- Actual Controls hook restores before the native mutator; post hook resuppresses.
do
 local api,c=suppression({row('One'),row('Two')});api:Apply({c});local pre,post
 a=assert(source:find('  local remapOK,remapError=',1,true))
 b=assert(source:find('  -- Suppress a newly applied',a,true))
 local e=setmetatable({RegisterHook=function(_,p,q)pre=p;post=q end,Config={Enabled=1},Suppression=api,
 RequestSuppressionSnapshot=function()api:Invalidate(c);api:Apply({c})end,log=error},{__index=_G})
 assert(load(source:sub(a,b-1),'remap-hooks','t',e))()
 pre();assert(c.Mappings[1].Key.KeyName=='One' and c.Mappings[2].Key.KeyName=='Two')
 table.remove(c.Mappings,1);post();assert(c.Mappings[1].Key.KeyName=='None')
 api:Restore();assert(c.Mappings[1].Key.KeyName=='Two')
end
-- A failed Key write preserves original SettingBehavior through Lua reload.
do
 local backing=row('One');local fail=true
 local proxy=setmetatable({}, {__index=backing,__newindex=function(_,k,v)
  if k=='Key' and fail then fail=false;error('injected')end;backing[k]=v
 end})
 local api,c,reload=suppression({proxy})
 assert(not pcall(function()api:Apply({c})end));assert(backing.SettingBehavior==2)
 api=reload();api:Apply({c});api:Restore()
 assert(backing.Key.KeyName=='One' and backing.SettingBehavior==0)
end
print('PASS native Controls remap transaction, ambiguous recovery preserves evidence, partial-write reload recovery')

do
 local objects={};local function obj(p)local o={path=p};objects[p]=o;return o end
 local native,assigned,external=obj('native'),obj('assigned'),obj('external')
 local w=obj('widget');w.EnhancedInputAction=native
 function w:SetEnhancedInputAction(v)self.EnhancedInputAction=v end
 local api=dofile('Scripts/action_indicators.lua')({valid=function(o)return o~=nil end,
 path=function(o)return o and o.path end,resolve=function(p)return objects[p]end,same=function(x,y)return x==y end})
 api:Set(w,assigned);w.EnhancedInputAction=external;api:Set(w,assigned)
 assert(api:RestoreAll() and w.EnhancedInputAction==external)
end
-- Delayed work is cancelled on the game thread when its owner is obsolete.
do
 local timers={};local current=true;local calls=0
 local api=dofile('Scripts/widget_setup.lua')({valid=function()return true end,enabled=function()return true end,
 key=function()return 'hud' end,relevant=function()return current end,queue=function(f)f()end,
 delay=function(_,f)timers[#timers+1]=f end,run=function()calls=calls+1;return 'children_missing'end,log=error})
 api:Request({});table.remove(timers,1)();assert(calls==1 and #timers==1)
 current=false;table.remove(timers,1)();assert(calls==1 and #timers==0)
 current=true;api:Request({});table.remove(timers,1)();assert(calls==2 and #timers==1)
end
print('PASS current indicator baseline and obsolete-owner cancellation without a readiness timeout')

-- A failed restoration write also survives a subsequent suppression retry.
do
 local backing=row('One');local fail=false
 local proxy=setmetatable({}, {__index=backing,__newindex=function(_,k,v)
  if k=='SettingBehavior' and fail then fail=false;error('restore interrupted')end;backing[k]=v
 end})
 local api,c,reload=suppression({proxy})
 api:Apply({c});fail=true
 assert(not pcall(function()api:Restore()end))
 api=reload();api:Apply({c});api:Restore()
 assert(backing.Key.KeyName=='One' and backing.SettingBehavior==0)
end
print('PASS partial restoration retains native baseline across reload and re-suppression')

-- Direct restoration after partial writes must finish without an Apply detour.
for _,kind in ipairs({'apply','restore'}) do for _,reloadFirst in ipairs({false,true}) do
 local backing=row('One');local failing
 local proxy=setmetatable({}, {__index=backing,__newindex=function(_,k,v)
  if failing==k then failing=nil;error('partial '..kind)end;backing[k]=v
 end})
 local api,c,reload=suppression({proxy})
 if kind=='apply' then failing='Key';assert(not pcall(function()api:Apply({c})end))
 else api:Apply({c});failing='SettingBehavior';assert(not pcall(function()api:Restore()end)) end
 if reloadFirst then api=reload() end
 assert(api:Restore())
 assert(backing.Key.KeyName=='One' and backing.SettingBehavior==0)
end end
-- Known native keys cannot donate the same original to a second blank row.
do
 local first,second=row('One'),row('Two')
 local api,c=suppression({first,second});api:Apply({c})
 first.Key={KeyName='One'};first.SettingBehavior=0
 table.insert(c.Mappings,1,{Action=other,Key={KeyName='Q'},SettingBehavior=0})
 api:Invalidate(c);api:Apply({c});api:Restore()
 assert(first.Key.KeyName=='One' and second.Key.KeyName=='Two')
end
-- Restore failure cannot take ownership of a separate external behavior change.
do
 local backing=row('One');local fail=false
 local proxy=setmetatable({}, {__index=backing,__newindex=function(_,k,v)
  if fail and k=='Key' then fail=false;error('restore write failed')end;backing[k]=v
 end})
 local second=row('Two');local api,c,reload=suppression({proxy,second});api:Apply({c})
 second.Key={KeyName='Two'};second.SettingBehavior=1
 fail=true;assert(not pcall(function()api:Restore()end));api=reload();api:Restore()
 assert(backing.SettingBehavior==0 and second.SettingBehavior==1)
end
-- Dead completed contexts are collectable during ordinary subsequent setup.
do
 local timers={};local weak=setmetatable({}, {__mode='v'})
 local api=dofile('Scripts/widget_setup.lua')({valid=function(o)return o and o.valid end,enabled=function()return true end,
 key=function(o)return o.id end,queue=function(f)f()end,delay=function(_,f)timers[#timers+1]=f end,
 run=function()return true end,log=error})
 for i=1,1000 do
  local context={id='hud'..i,valid=true};weak[i]=context
  api:Request(context,'hud');table.remove(timers,1)();context.valid=false
 end
 collectgarbage('collect');local retained=0;for _ in pairs(weak)do retained=retained+1 end
 assert(retained<=1,'completed cache must release obsolete contexts without global invalidation')
end
print('PASS direct Restore/reload, one-to-one duplicate provenance, external state preservation and bounded completed cache')
