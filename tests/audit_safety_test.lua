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
local visuals=loadconfig('[More Options]\nPrimarySize=500\nPrimaryOpacity=-2\nSecondarySize=10\nSecondaryOpacity=120')
assert(visuals.PrimarySize==200 and visuals.PrimaryOpacity==0 and visuals.SecondarySize==25 and visuals.SecondaryOpacity==100,
 'visual ranges must remain safe for manually edited configuration')
local defaults=loadconfig('')
assert(defaults.PrimarySize==100 and defaults.PrimaryOpacity==100 and defaults.SecondarySize==70 and defaults.SecondaryOpacity==80)
print('PASS schema precedence, explicit primary, legacy coordinates, visual defaults/ranges and global threshold')
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
print('PASS completed widget setup releases obsolete contexts')
