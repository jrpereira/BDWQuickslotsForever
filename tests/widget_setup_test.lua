local timers,jobs,logs={},{},{}
local enabled=true
local calls=0
local result='children_missing'
local setup=dofile('Scripts/widget_setup.lua')({valid=function(o)return o and o.valid end,
 key=function(o)return o.id end,enabled=function()return enabled end,
 delay=function(ms,fn)assert(ms==100);timers[#timers+1]=fn end,
 queue=function(fn)jobs[#jobs+1]=fn end,log=function(s)logs[#logs+1]=s end,
 run=function()calls=calls+1;if result=='error' then error('fail')end;return result end})
local function fire() local fn=table.remove(timers,1);assert(fn);fn();fn=table.remove(jobs,1);if fn then fn()end end
setup:Request({id='invalid',valid=false});assert(#timers==0)
local w={id='wheel',valid=true}
setup:Request(w);setup:Request(w);assert(#timers==1)
fire();assert(calls==1 and #timers==1,'missing children reschedule')
w.valid=false;fire();assert(calls==1 and #timers==0,'invalid context stops without retry')
w.valid=true;setup:Request(w);result=true;fire();assert(calls==2 and #timers==0)
setup:Request(w);assert(#timers==0,'completed setup must not repeat')
setup:Invalidate();setup:Request(w);setup:Invalidate();setup:Request(w)
fire();assert(calls==2,'stale delay cannot run');fire();assert(calls==3)
setup:Invalidate();setup:Request(w);table.remove(timers,1)();w.valid=false
table.remove(jobs,1)();assert(calls==3 and #timers==0,'recheck validity on game thread')
w.valid=true;setup:Request(w);result='error';fire();assert(#logs==1 and #timers==0,'errors never retry')
setup:Request(w);result=nil;fire();assert(#timers==0,'non-child dependency never retries')
setup:Request(w);enabled=false;fire();assert(#timers==0)
print('PASS widget setup: only missing children retry, invalid contexts/errors stop, deduplication, completed setup and stale-job cancellation')

-- Exercise the actual independent indicator and format functions.
local f=assert(io.open('Scripts/main.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local function desired_wheel_format(',1,true))
local b=assert(source:find('local function watch_widget(',a,true))
local directions={'Left','Top','Right','Bottom'}
local function bindings()local t={}for _,d in ipairs(directions)do t[d]={}end;return t end
local hud={id='hud',class='WBP_GameHUD_C'}
local switcher={id='switcher',GetOuter=function()return hud end}
hud.QuickslotsSwitcher=switcher
hud.WBP_AA_Quickslots={WBP_AA_Quickslots_Bindings=bindings()}
hud.WBP_HUD_Quickslots={WBP_HUD_Quickslots_Bindings=bindings()}
local delayed,queued,steps={},{},{}
local lastFormat
local env=setmetatable({scripts='Scripts',Config={Enabled=1,ShowBothWheels=0,SwapAbilitiesWithConsumables=0,
 AbilitiesX=20,AbilitiesY=40,ConsumablesX=40,ConsumablesY=-420},Enhanced={ready=true},
 ShortcutTargets={SetHUD=function()end},SLOT_WIDGET=directions,valid=function(o)return type(o)=='table' and not o.dead end,
 safe=function(o,k)return o and o[k]end,object_path=function(o)return o.id end,
 fullname=function(o)return (o.class or 'Widget')..' '..o.id end,
 same=function(x,y)return x==y end,belongs=function()return true end,
 bindings_widget=function(o,props)for _,key in ipairs(props)do if o[key] then return o[key]end end end,
 WheelLayout={Update=function(_,h,s,ability,consumable,both,ax,ay,cx,cy)
  steps[#steps+1]='layout';lastFormat={both=both,ay=ay,cy=cy};return true end},
 hide_swap_prompt=function()end,
 override_icons=function()steps[#steps+1]='actions';return 8 end,
 ExecuteWithDelay=function(_,fn)delayed[#delayed+1]=fn end,
 ExecuteInGameThread=function(fn)queued[#queued+1]=fn end,log=function()end}, {__index=_G})
local request,indicators,formats,apply,desired=assert(load(source:sub(a,b-1)..
 '\nreturn request_wheel_setup,IndicatorSetup,FormatSetup,apply_wheel_format,desired_wheel_format','actual-wheel-setup','t',env))()
local function advance()table.remove(delayed,1)();while #queued>0 do table.remove(queued,1)()end end
request(hud,'hud');request(switcher,'switcher');assert(#delayed==1,'indicator and format setup share a timer')
local child=hud.WBP_AA_Quickslots.WBP_AA_Quickslots_Bindings.Bottom
hud.WBP_AA_Quickslots.WBP_AA_Quickslots_Bindings.Bottom=nil
advance()
assert(table.concat(steps,',')=='layout' and #delayed==1,'format does not wait for indicators')
hud.WBP_AA_Quickslots.WBP_AA_Quickslots_Bindings.Bottom=child
advance();assert(table.concat(steps,',')=='layout,actions' and #delayed==0)
request(hud,'hud');assert(#delayed==1,'later calls still apply panel format')
advance();assert(table.concat(steps,',')=='layout,actions,layout','later calls never reconnect indicators')
formats:Invalidate();request(hud,'hud');assert(#delayed==1);advance()
assert(table.concat(steps,',')=='layout,actions,layout,layout','format changes preserve indicator completion')
local oldButton=hud.WBP_AA_Quickslots.WBP_AA_Quickslots_Bindings.Bottom
oldButton.dead=true
hud.WBP_AA_Quickslots.WBP_AA_Quickslots_Bindings.Bottom={}
local beforeReplacement=#steps
request(switcher,'switcher');advance()
assert(steps[beforeReplacement+1]=='actions' and steps[beforeReplacement+2]=='layout',
 'surviving HUD must connect replacement indicator children')
request(hud,'hud');assert(#delayed==1,'unchanged replacement indicators remain once-only');advance()
env.Enhanced.ready=false
assert(desired()=='single' and apply(hud,desired()) and not lastFormat.both)
env.Config.ShowBothWheels=1
assert(desired()=='consumables_above' and apply(hud,desired()) and lastFormat.cy<lastFormat.ay)
env.Config.SwapAbilitiesWithConsumables=1
assert(desired()=='abilities_above' and apply(hud,desired()) and lastFormat.ay<lastFormat.cy)
assert(not apply(hud,'invalid'))
indicators:Invalidate();formats:Invalidate();request(hud,'hud');hud.dead=true
local before=#steps;advance();assert(#steps==before and #delayed==0)
print('PASS independent setup: format without indicators/input, one-time action assignment, format changes preserve setup, three formats and invalid-context cancellation')
