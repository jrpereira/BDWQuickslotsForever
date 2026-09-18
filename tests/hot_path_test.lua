local f=assert(io.open('Scripts/main.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:find('local function gameplay_context_signature(',1,true))
local stop=assert(source:find('local function setup_enhanced_input(',start,true))
local scans,names=0,0
local env=setmetatable({valid=function(o) return type(o)=='table' and o.valid end,
 safe=function(o,k) return o[k] end,unwrap=function(o) return o end,
 fullname=function(o) names=names+1;return o.name end,
 each_container=function(map,fn) scans=scans+1;for k,v in pairs(map) do fn(k,v) end end}, {__index=_G})
local signature=assert(load(source:sub(start,stop-1)..'\nreturn gameplay_context_signature','context-scan','t',env))()
local draw={valid=true,name='/transient/draw'};local ow={valid=true,name='IMC_OW.IMC_OW'}
local pi={valid=true,AppliedInputContexts={[draw]=10001,[ow]=-1}}
local route,present=signature(pi,draw);assert(route==ow.name and present and scans==1 and names==3)
pi.AppliedInputContexts[draw]=nil
route,present=signature(pi,draw);assert(route==ow.name and not present and scans==2)
local labelStart=assert(source:find('local function key_label(',1,true))
local labelEnd=assert(source:find('for i=0,9 do VK_TO_FKEY',labelStart,true))
local label=assert(load(source:sub(labelStart,labelEnd-1)..'\nreturn key_label','key-labels','t',setmetatable({VK_TO_FKEY={}}, {__index=_G})))()
assert(label(5)=='M4' and label(6)=='M5' and label(81)=='Q')
print('PASS: one input-context pass provides routing and draw presence; compact mouse labels')
