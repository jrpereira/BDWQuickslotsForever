-- Validate the category contract using the installed menu's parser/model, read-only.
local choicesPath=assert(arg[1],"pass the installed DawnwalkerModMenu Scripts/choices.lua path")
local choices=dofile(choicesPath)
local file=assert(io.open("mod_settings.ini","rb")); local settings=choices.parse(file:read("*a")); file:close()
local model=choices.open({id="QuickslotsForever-wheel-test",testOnly=true,choices=settings})
assert(not model.error,model.error)
local display,options
options={}
for i,row in ipairs(settings) do
  if row.id=="ShowWheels" then display=i; assert(row.default==2 and row.group=="General Settings") end
  assert(row.group~="Visuals" and row.group~="Wheels")
  if row.group=="More Options" or row.group=="Primary Visuals" or row.group=="Secondary" then options[#options+1]=i end
end
assert(display and #options==9,"display selector and threshold plus eight visual controls")
for _,value in ipairs({1,2}) do
  model:set(display,value)
  local visible=model:visibility()
  for _,i in ipairs(options)do assert(visible[i],'More Options stays available in either layout')end
end
print("PASS: real Mod Menu display selector and bottom visual categories")

local byId={};for i,row in ipairs(settings)do byId[row.id]=i end
local interaction=assert(byId.InteractionMode)
assert(settings[interaction].values[1]==0 and settings[interaction].values[2]==1,'Independent/Selective values follow the runtime')
assert(model.pending[interaction]==0,'existing eight-key behavior remains default')
local function shown(id)return model:visibility()[assert(byId[id])]end
for mode=0,1 do
  model:set(interaction,mode)
  for slot=1,4 do
    assert(shown('Ability'..slot)==(mode==0) and shown('Consumable'..slot)==(mode==0))
  end
  assert(shown('SecondaryWheelKey')==(mode==1) and shown('SecondaryWheelMode')==(mode==1))
end
model:set(interaction,1)
local secondaryMode=assert(byId.SecondaryWheelMode)
assert(settings[secondaryMode].values[1]==0 and settings[secondaryMode].values[2]==2 and model.pending[secondaryMode]==2)
assert(not shown('PrimaryWheelKey'))
model:set(secondaryMode,0);assert(shown('PrimaryWheelKey'))
model:set(secondaryMode,2);assert(not shown('PrimaryWheelKey'))
print('PASS Independent/Selective tabs and Tap Trigger/Hold Sustained controls')

assert(byId.HoldThresholdMs and not byId.PrimaryHoldThresholdMs and not byId.SecondaryHoldThresholdMs)
assert(settings[byId.HoldThresholdMs].label=='Hold threshold')
model:set(byId.HoldThresholdMs,375)
for mode=0,1 do for primary=0,1 do
 model:set(interaction,mode);model:set(byId.PrimaryWheel,primary)
 assert(model.pending[byId.HoldThresholdMs]==375,'mode/primary must not alter global threshold')
end end
print('PASS one global Hold threshold remains unchanged across all modes and primary choices')
