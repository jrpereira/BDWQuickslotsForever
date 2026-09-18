local factory=dofile('Scripts/event_work.lua')
local jobs,timers,calls,logs={},{},{},{}
local enabled,fail=true,false
local work
work=factory({attempts=3,enabled=function()return enabled end,
 queue=function(fn)jobs[#jobs+1]=fn end,
 delay=function(ms,fn)assert(ms==500);timers[#timers+1]=fn end,
 log=function(s)logs[#logs+1]=s end,
 run=function(name)
  calls[name]=(calls[name] or 0)+1
  work:Request(name)
  if fail then error('unavailable') end
  return true
 end})
local function drain() local fn=table.remove(jobs,1) or table.remove(timers,1);if fn then fn();return true end end
local function settle()for i=1,30 do if not drain() then return end end;error('did not settle')end
assert(#jobs==0 and #timers==0,'idle has no callback')
work:Request('input');work:Request('hud')
assert(#jobs==1 and #timers==0,'immediate coalesced dispatch')
settle();assert(calls.input==1 and calls.hud==1 and #timers==0,'own events settle')
fail=true;work:Request('input');settle()
assert(calls.input==4 and #logs==1,'bounded failure retries')
fail=false;work:Request('input');work:Invalidate();work:Request('hud');drain();drain()
assert(calls.input==4 and calls.hud==2,'stale queued job cannot erase new request')
fail=true;work:Request('input');drain();assert(#timers==1)
work:Invalidate();fail=false;work:Request('hud');settle()
assert(calls.input==5 and calls.hud==3,'stale delayed retry cannot affect new work')
work:Request('input');enabled=false;settle();assert(calls.input==5)
local attempts=0
local broken=factory({attempts=3,enabled=function()return true end,log=function()end,
 queue=function()attempts=attempts+1;error('queue unavailable')end,
 delay=function(_,fn)timers[#timers+1]=fn end,run=function()error('unexpected')end})
broken:Request('hud');settle();assert(attempts==3,'dispatch errors bounded')
local failures=0
local noTimer=factory({enabled=function()return true end,log=function()failures=failures+1 end,
 queue=function(fn)jobs[#jobs+1]=fn end,delay=function()error('timer unavailable')end,
 run=function()return false end})
noTimer:Request('hud');settle();assert(failures==1 and #jobs==0 and #timers==0)
print('PASS: event dispatch, idle zero callbacks, bounded retries, stale jobs/timers, no self-loop and failed scheduling')

local pendingJobs,pendingTimers={},{}
local n=0
local scoped=factory({attempts=6,enabled=function()return true end,log=function()end,
 queue=function(fn)pendingJobs[#pendingJobs+1]=fn end,delay=function(_,fn)pendingTimers[#pendingTimers+1]=fn end,
 run=function()n=n+1;return false end})
scoped:Request('input');table.remove(pendingJobs,1)()
for i=1,5 do
 for j=1,20 do scoped:Request('input')end
 table.remove(pendingTimers,1)();table.remove(pendingJobs,1)()
end
assert(n==6 and #pendingTimers==0,'100 duplicate pending events cannot replenish six-attempt budget')
scoped:Invalidate();scoped:Request('input');table.remove(pendingJobs,1)()
assert(n==7 and #pendingTimers==1,'new lifecycle generation gets a fresh budget')
print('PASS retry budget: duplicates coalesce without replenishment; new generation resumes')
