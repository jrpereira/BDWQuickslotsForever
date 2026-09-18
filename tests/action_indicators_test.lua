local objects={}
local function obj(name)local o={name=name};objects[name]=o;return o end
local native,mod,other=obj('native'),obj('mod'),obj('other')
local w=obj('widget');w.EnhancedInputAction=native;w.Icon='untouched';local writes=0
function w:SetEnhancedInputAction(a)self.EnhancedInputAction=a;writes=writes+1 end
local api=dofile('Scripts/action_indicators.lua')({valid=function(o)return o and not o.dead end,
 path=function(o)return o and o.name end,resolve=function(p)return objects[p]end,same=function(a,b)return a==b end})
assert(api:Set(w,mod) and writes==1 and w.Icon=='untouched')
assert(api:Set(w,mod) and writes==1,'repeat lifecycle wiring must not repaint')
assert(api:RestoreAll() and w.EnhancedInputAction==native)
assert(api:Set(w,mod));w.EnhancedInputAction=other
assert(api:RestoreAll() and w.EnhancedInputAction==other,'preserve external changes')
api:Set(w,mod);api:Forget();api:RestoreAll();assert(w.EnhancedInputAction==mod)
print('PASS native indicators: idempotent action wiring, no Icon writes, owned restoration and world teardown')
