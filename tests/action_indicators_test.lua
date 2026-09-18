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

-- Rebuilt HUDs do not accumulate dead restoration records; live HUDs survive.
local journal='';local saves=0;local live={native=native,mod=mod}
local factory=dofile('Scripts/action_indicators.lua')
local env={valid=function(o)return o and not o.dead end,path=function(o)return o and o.name end,
 resolve=function(p)return live[p]end,same=function(a,b)return a==b end,
 load=function()return journal end,save=function(s)journal=s;saves=saves+1 end}
local tracked=factory(env)
local survivor={name='survivor',EnhancedInputAction=native,SetEnhancedInputAction=w.SetEnhancedInputAction}
live.survivor=survivor;assert(tracked:Set(survivor,mod))
for i=1,100 do
 local rebuilt={name='rebuilt'..i,EnhancedInputAction=native,SetEnhancedInputAction=w.SetEnhancedInputAction}
 live[rebuilt.name]=rebuilt;assert(tracked:Set(rebuilt,mod));live[rebuilt.name]=nil
 local count=0;for _ in journal:gmatch('[^\n]+') do count=count+1 end
 assert(count<=2,'dead native indicator records must not grow across HUD rebuilds')
end
tracked:Prune();local before=saves
assert(tracked:Set(survivor,mod) and saves==before,'completed wiring does not scan or serialize')
tracked=factory(env);assert(tracked:RestoreAll() and survivor.EnhancedInputAction==native and journal=='')
print('PASS native indicator journal stays bounded across100 HUD replacements and restores surviving widgets after reload')
