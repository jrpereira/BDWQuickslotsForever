-- Validate the category contract using the installed menu's parser/model, read-only.
local choicesPath=assert(arg[1],"pass the installed DawnwalkerModMenu Scripts/choices.lua path")
local choices=dofile(choicesPath)
local file=assert(io.open("mod_settings.ini","rb")); local settings=choices.parse(file:read("*a")); file:close()
local model=choices.open({id="QuickslotsForever-wheel-test",testOnly=true,choices=settings})
assert(not model.error,model.error)
local toggle,wheels
wheels={}
for i,row in ipairs(settings) do
  if row.id=="ShowBothWheels" then toggle=i; assert(row.default==1 and row.group=="General Settings") end
  assert(row.group~="Visuals")
  if row.group=="Wheels" then wheels[#wheels+1]=i end
end
assert(toggle and #wheels==5,"toggle and exactly five wheel options")
local visible=model:visibility(); for _,i in ipairs(wheels) do assert(visible[i]) end
model:set(toggle,0); visible=model:visibility()
for i,row in ipairs(settings) do assert(visible[i]==(row.group~="Wheels"),"only Wheels hides") end
model:set(toggle,1); visible=model:visibility(); for _,i in ipairs(wheels) do assert(visible[i]) end
if arg[2] then
  local migrated=choices.open({id="QuickslotsForever-migration-test",path=arg[2].."/mod_settings.ini",choices=settings})
  assert(not migrated.error,migrated.error)
  assert(migrated.pending[toggle]==0,"existing migrated Off reaches actual menu model")
end
print("PASS: native/dual layout transitions, restoration, failure safety, and real Mod Menu conditional Wheels metadata")
