-- Exercise the real external config manager and DMM parser without disk writes.
local choices=dofile(assert(arg[1],'DMM choices.lua required'))
local init=dofile(assert(arg[2],'MMD init_config.lua required'))
local function read(path)local f=assert(io.open(path,'rb'));local text=f:read('*a');f:close();return text end
local manifest=read('mod_settings.ini')
local source=read('Scripts/main.lua')
local a=assert(source:find('local function parse_ini(',1,true))
local b=assert(source:find('local LastConfigText=',a,true))
local loadconfig=assert(load(source:sub(a,b-1)..'\nreturn load_config','runtime-config','t',setmetatable({
 readall=function()return ''end,trim=function(s)return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$',''))end},{__index=_G})))()
local function memory(original)
 local files={['fixture/config.ini']=original}
 local fs={read=function(p)return files[p]end,write=function(p,t)files[p]=t end,
  rename=function(a,b)assert(files[a] and not files[b]);files[b]=files[a];files[a]=nil end,
  remove=function(p)files[p]=nil end}
 return fs,files
end
local function lines_preserved(old,new)
 local at=1
 for line in old:gmatch('[^\n]*\n')do
  local first,last=new:find(line,at,true)
  assert(first,'original line was altered: '..line);at=last+1
 end
end
local count=0
for _,show in ipairs({'missing','0','1'})do
 for _,primary in ipairs({'missing','0','1'})do
  for _,swap in ipairs({'missing','0','1'})do
   for _,newline in ipairs({'\n','\r\n'})do
    for _,overrides in ipairs({'','[More Options]\nConsumablesX=91\n','[More Options]\nPrimaryX=101\nPrimaryY=102\nSecondaryX=103\nSecondaryY=104\n'})do
     local text='; personal choices\n[General]\nEnabled=1\nHoldThresholdMs=375\n'
     if show~='missing' then text=text..'ShowBothWheels='..show..'\n' end
     if primary~='missing' then text=text..'PrimaryWheel='..primary..'\n' end
     text=text..'[Position Modifiers]\nAbilitiesX=12\nAbilitiesY=34\nConsumablesX=56\nConsumablesY=-78\n'
     if swap~='missing' then text=text..'SwapAbilitiesWithConsumables='..swap..'\n' end
     text=text..overrides..'[Bindings]\n'
     for _,group in ipairs({'Ability','Consumable'})do for slot=1,4 do
      text=text..group..slot..'='..(60+slot)..'\n'..group..slot..'Mode='..(slot%2)..'\n'
     end end
     text=text:gsub('\n',newline)
     local fs,files=memory(text)
     local provider={id='qsf-migration',path='fixture/mod_settings.ini'}
     local plan=init.plan(provider,manifest,choices,fs)
     lines_preserved(text,plan.content)
     local before,after=loadconfig(text),loadconfig(plan.content)
     for _,field in ipairs({'PrimaryWheel','ShowBothWheels','HoldThresholdMs','PrimaryX','PrimaryY','SecondaryX','SecondaryY'})do
      assert(before[field]==after[field],field..' changed during migration '..primary..'/'..swap)
     end
     for _,group in ipairs({'Ability','Consumable'})do for slot=1,4 do for _,suffix in ipairs({'','Mode'})do
      local key=group..slot..suffix;assert(before[key]==after[key],'personal binding changed')
     end end end
     init.commit(plan,fs)
     assert(init.plan(provider,manifest,choices,fs).content==files['fixture/config.ini'],'migration is idempotent')
     local settings=choices.parse(manifest)
     choices.fs=fs
     provider.choices=settings
     local model=choices.open(provider);assert(not model.error,model.error)
     local byId={};for i,row in ipairs(settings)do byId[row.id]=i end
     assert(model.pending[byId.ShowWheels]==(before.ShowBothWheels==0 and 1 or 2))
     for _,key in ipairs({'PrimaryWheel','PrimaryX','PrimaryY','SecondaryX','SecondaryY','HoldThresholdMs'})do
      assert(model.pending[byId[key]]==before[key],key..' differs in menu')
     end
     model:set(byId.HoldThresholdMs,400);assert(model:apply())
     local applied=loadconfig(files['fixture/config.ini'])
     assert(applied.HoldThresholdMs==400 and applied.ShowBothWheels==before.ShowBothWheels)
     assert(applied.PrimaryX==before.PrimaryX and applied.SecondaryY==before.SecondaryY)
     count=count+1
    end
   end
  end
 end
end
for _,text in ipairs({
 '[General]\nShowBothWheels=7\n',
 '[General]\nPrimaryWheel=3\n',
 '[Position Modifiers]\nSwapAbilitiesWithConsumables=invalid\n',
 '[Position Modifiers]\nAbilitiesX=1001\n',
 '[General]\nShowBothWheels=0\nShowBothWheels=1\n',
 '[General]\nShowWheels=3\n',
})do
 local fs,files=memory(text)
 assert(not pcall(init.plan,{id='invalid',path='fixture/mod_settings.ini'},manifest,choices,fs),'bad migration accepted')
 assert(files['fixture/config.ini']==text and files['fixture/config.ini.mmd-init.tmp']==nil,'failed plan wrote config')
end
-- New destinations take precedence even over malformed obsolete sources.
local text='[General]\nShowWheels=1\nShowBothWheels=bad\nPrimaryWheel=1\n[More Options]\nPrimaryX=1\nPrimaryY=2\nSecondaryX=3\nSecondaryY=4\n[Position Modifiers]\nAbilitiesX=bad\nSwapAbilitiesWithConsumables=bad\n'
local fs=memory(text)
local plan=init.plan({id='explicit',path='fixture/mod_settings.ini'},manifest,choices,fs)
local c=loadconfig(plan.content)
assert(c.ShowBothWheels==0 and c.PrimaryX==1 and c.SecondaryY==4)
print('PASS '..count..' migration/menu/Apply cases, exact legacy-line preservation, bindings, idempotence, destination precedence and invalid-input refusal')

-- Use the owned open/parse adapter against actual DMM, including recovery.
for _,failure in ipairs({'source','write','rename'})do
 local actual=dofile(arg[1])
 local good='[General]\nShowBothWheels=0\nPrimaryWheel=1\nHoldThresholdMs=375\n[Position Modifiers]\nAbilitiesX=12\nAbilitiesY=34\nConsumablesX=56\nConsumablesY=-78\nSwapAbilitiesWithConsumables=obsolete\n'
 local original=failure=='source' and good:gsub('ShowBothWheels=0','ShowBothWheels=broken') or good
 local fs,files=memory(original)
 files['fixture/mod_settings.ini']=manifest
 local write,rename=fs.write,fs.rename
 if failure=='write' then fs.write=function(path,text)write(path,text);error('simulated short write')end end
 if failure=='rename' then fs.rename=function(a,b)
  if a:find('.mmd-init.tmp',1,true)then error('simulated install failure')end
  return rename(a,b)
 end end
 actual.fs=fs
 assert(init.install(actual,fs))
 local provider={id='gated',path='fixture/mod_settings.ini',choices=actual.parse(manifest)}
 local model=actual.open(provider)
 assert(model.error and not model:apply(),'migration failure must block real DMM Apply')
 assert(files['fixture/config.ini']==original,'failed migration changed personal bytes')
 assert(not files['fixture/config.ini.mmd-init.tmp'] and not files['fixture/config.ini.mmd-init.bak'],'recoverable failure left transactions behind')
 fs.write,fs.rename=write,rename;files['fixture/config.ini']=good
 model=actual.open(provider);assert(not model.error,model.error)
 local byId={};for i,row in ipairs(provider.choices)do byId[row.id]=i end
 assert(model.pending[byId.ShowWheels]==1 and model.pending[byId.PrimaryX]==12)
 assert(model.pending[byId.PrimaryWheel]==1 and model.pending[byId.SecondaryY]==-78)
 model:set(byId.HoldThresholdMs,400);assert(model:apply())
 assert(loadconfig(files['fixture/config.ini']).HoldThresholdMs==400)
end
print('PASS actual DMM migration gate: invalid source, partial write, failed rename/rollback, original bytes and corrected-source retry')
