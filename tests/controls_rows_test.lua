local make=dofile('Scripts/controls_rows.lua')
local live={}
local active=true
local failOpacity=false
local serial=0
local function row(path,id,opacity,enabled,key)
  serial=serial+1
  local r={path=path,id=id,opacity=opacity,enabled=enabled,key=key,instance=serial}
  live[path]=r
  return r
end
local left=row('/left','player_quickslot_left',0.8,true,'Q')
local jump=row('/jump','player_jump',1,true,'Q')
local alreadyDisabled=row('/top','player_quickslot_top',0.6,false,'1')
local unknown=row('/unknown',nil,1,true,'Q')
local panel={tag='UI.Settings.Controls',rows={left,jump,alreadyDisabled,unknown}}
local targets={player_quickslot_left=true,player_quickslot_top=true}
local api=make({
  active=function() return active end,
  valid=function(o) return o~=nil and not o.dead end,
  tag=function(o) return o.tag end,
  rows=function(p,fn) for _,r in ipairs(p.rows) do fn(r) end end,
  resolve=function(path) return live[path] end,
  identity=function(r) return r.id end,
  instance=function(r) return r.instance end,
  path=function(r) return r.path end,
  target=function(id) return targets[id]==true end,
  state=function(r) return r.opacity,r.enabled end,
  enabled=function(r,value) r.enabled=value end,
  opacity=function(r,value) if failOpacity then error('simulated setter failure') end; r.opacity=value end,
})
assert(api:Update(panel)==2)
assert(not left.enabled and math.abs(left.opacity-0.32)<1e-9)
assert(jump.enabled and jump.opacity==1 and unknown.enabled)
api:Update(panel);assert(math.abs(left.opacity-0.32)<1e-9,'must not compound dimming')
active=false;api:Update(panel)
assert(left.enabled and left.opacity==0.8)
assert(not alreadyDisabled.enabled and alreadyDisabled.opacity==0.6)
active=true;panel.tag='UI.Settings.Audio';assert(api:Update(panel)==0 and left.enabled)
panel.tag='UI.Settings.Controls';api:Update(panel)
-- A replaced row with the same path but another mapping must not receive old state.
local replacement=row('/left','player_jump',0.9,true,'Q')
api:Restore();assert(replacement.enabled and replacement.opacity==0.9)
panel.rows={replacement};assert(api:Update(panel)==0)
local original=row('/reused','player_quickslot_left',0.75,true,'1')
panel.rows={original};api:Update(panel)
local reused=row('/reused','player_quickslot_left',0.9,false,'1')
api:Restore();assert(reused.opacity==0.9 and not reused.enabled)
panel.rows={alreadyDisabled};api:Update(panel);alreadyDisabled.dead=true;api:Restore()
alreadyDisabled.dead=false;alreadyDisabled.opacity=0.7
api:Update(panel);api:Forget();api:Restore()
assert(math.abs(alreadyDisabled.opacity-0.28)<1e-9,'world reset must drop stale restoration state')
-- Native list widgets can recycle the same instance for a different action.
local recycled=row('/recycled','player_quickslot_left',0.85,true,'Q')
panel.rows={recycled};assert(api:Update(panel)==1)
recycled.id='player_jump';assert(api:Update(panel)==0)
assert(recycled.enabled and recycled.opacity==0.85,'rebound unrelated action must be restored')
recycled.id='player_quickslot_left';api:Update(panel)
recycled.id='player_quickslot_top';api:Update(panel)
assert(math.abs(recycled.opacity-0.34)<1e-9,'target-to-target rebinding must not compound dimming')
api:Restore();assert(recycled.opacity==0.85 and recycled.enabled)
-- Identity disappearing also restores an owned instance without guessing its action.
api:Update(panel);recycled.id=nil;api:Update(panel)
assert(recycled.opacity==0.85 and recycled.enabled)
-- Unavailable or invalid baseline state must not cause writes.
local bad=row('/bad','player_quickslot_left',0/0,true,'1')
panel.rows={bad};assert(api:Update(panel)==0 and bad.enabled)
bad.opacity=1;bad.enabled=nil;assert(api:Update(panel)==0 and bad.opacity==1)
bad.enabled=true;bad.instance=nil;assert(api:Update(panel)==0 and bad.enabled)
assert(api:Update(nil)==0)
-- If dimming fails after disabling, retain the snapshot for explicit restoration.
local failure=row('/failure','player_quickslot_left',0.9,true,'1')
panel.rows={failure};failOpacity=true
assert(not pcall(function() api:Update(panel) end))
assert(not failure.enabled and failure.opacity==0.9)
assert(not pcall(function() api:Restore() end),'failed restore should be surfaced')
failOpacity=false;api:Restore()
assert(failure.enabled and failure.opacity==0.9,'failed restore must not discard original state')
local source=assert(io.open('Scripts/controls_rows.lua','rb'));local text=source:read('*a');source:close()
assert(not text:find('LoopAsync',1,true) and not text:find('ExecuteWithDelay',1,true))
print('PASS: identity-only targeting, same-key exclusion, stable dimming, restoration, recycled/replaced/dead rows, missing data, setter failures and world reset')
