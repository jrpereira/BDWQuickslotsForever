-- QuickslotsForever v0.3.48
-- UE4SS Lua mod for The Blood of Dawnwalker.
-- Gameplay objects are resolved lazily. A one-time activatable-widget snapshot
-- seeds the input gate so reloading this mod inside an open menu is safe.

local TAG="[QuickslotsForever]"
local VERSION="0.3.48"

local function log(s) print(TAG.." "..tostring(s).."\n") end
local function op_valid(o) return o:IsValid() end
local function valid(o) if o==nil then return false end local ok,v=pcall(op_valid,o); return ok and v==true end
local function safe(o,k) local ok,v=pcall(function() return o[k] end); if ok then return v end end
local function fullname(o) if not valid(o) then return "<invalid>" end local ok,v=pcall(function() return o:GetFullName() end); return ok and tostring(v) or "<name>" end
local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function readall(path) local f=io.open(path,"rb"); if not f then return nil end local s=f:read("*a"); f:close(); return s end
local function writeall(path,s) local f=assert(io.open(path,"wb")); f:write(s); f:close() end

local src=(debug.getinfo(1,"S").source or ""):gsub("^@","")
local scripts=src:match("^(.*)[/\\][^/\\]+$") or "."
local moddir=scripts:match("^(.*)[/\\]Scripts$") or scripts
local CONFIG_PATH=moddir.."/config.ini"

local HookStats=dofile(scripts.."/hook_stats.lua")(os.time)
local EngineRegisterHook=RegisterHook
local function RegisterHook(path,pre,post)
  return EngineRegisterHook(path,HookStats:Wrap(path..' [pre]',pre),HookStats:Wrap(path..' [post]',post))
end
local EngineNotifyOnNewObject=NotifyOnNewObject
local function NotifyOnNewObject(path,callback)
  return EngineNotifyOnNewObject(path,HookStats:Wrap(path..' [created]',callback))
end
local EngineLoadMapPre=RegisterLoadMapPreHook
local function RegisterLoadMapPreHook(callback)
  return EngineLoadMapPre(HookStats:Wrap('LoadMap [pre]',callback))
end
local EngineLoadMapPost=RegisterLoadMapPostHook
local function RegisterLoadMapPostHook(callback)
  return EngineLoadMapPost(HookStats:Wrap('LoadMap [post]',callback))
end
local statsOk,statsError=pcall(RegisterConsoleCommandHandler,'ec_hook_stats',function(_,args)
  if args and args[1]=='reset' then HookStats:Reset();log('Hook counters reset.')
  else HookStats:Report(log) end
  return true
end)
if not statsOk then log('Hook counter command unavailable: '..tostring(statsError)) end


local function parse_ini(text)
  local ini={}; local sec=""
  ini[sec]={}
  for line in (text or ""):gmatch("[^\r\n]+") do
    local h=trim(line):match("^%[([^%]]+)%]$")
    if h then sec=trim(h); ini[sec]=ini[sec] or {}
    elseif not trim(line):match("^[;#]") and trim(line)~="" then
      local k,v=line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
      if k then ini[sec]=ini[sec] or {}; ini[sec][trim(k)]=trim(v) end
    end
  end
  return ini
end
local function iv(ini,sec,key,default) local v=ini[sec] and tonumber(ini[sec][key]); if v==nil then return default end return math.floor(v) end
local VK_TO_FKEY={
 [0x01]="LeftMouseButton",[0x02]="RightMouseButton",[0x04]="MiddleMouseButton",[0x05]="ThumbMouseButton",[0x06]="ThumbMouseButton2",
 [0x30]="Zero",[0x31]="One",[0x32]="Two",[0x33]="Three",[0x34]="Four",[0x35]="Five",[0x36]="Six",[0x37]="Seven",[0x38]="Eight",[0x39]="Nine",
 [0x41]="A",[0x42]="B",[0x43]="C",[0x44]="D",[0x45]="E",[0x46]="F",[0x47]="G",[0x48]="H",[0x49]="I",[0x4A]="J",[0x4B]="K",[0x4C]="L",[0x4D]="M",[0x4E]="N",[0x4F]="O",[0x50]="P",[0x51]="Q",[0x52]="R",[0x53]="S",[0x54]="T",[0x55]="U",[0x56]="V",[0x57]="W",[0x58]="X",[0x59]="Y",[0x5A]="Z",
 [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",[0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",[0x7A]="F11",[0x7B]="F12",
 [0x09]="Tab",[0x20]="SpaceBar",[0x21]="PageUp",[0x22]="PageDown",[0x23]="End",[0x24]="Home",[0x25]="Left",[0x26]="Up",[0x27]="Right",[0x28]="Down",[0x2D]="Insert",[0x2E]="Delete",[0xDC]="Backslash",[0xBA]="Semicolon",[0xBB]="Equals",[0xBC]="Comma",[0xBD]="Hyphen",[0xBE]="Period",[0xBF]="Slash",[0xC0]="Tilde",[0xDB]="LeftBracket",[0xDD]="RightBracket",[0xDE]="Apostrophe",
}
local function key_label(vk)
  local mouse={[1]="M1",[2]="M2",[4]="M3",[5]="M4",[6]="M5"}
  if mouse[vk] then return mouse[vk] end
  if vk>=48 and vk<=57 then return string.char(vk) end
  if vk>=65 and vk<=90 then return string.char(vk) end
  if vk>=112 and vk<=123 then return "F"..tostring(vk-111) end
  local labels={[9]="Tab",[32]="Space",[33]="PgUp",[34]="PgDn",[35]="End",[36]="Home",
    [37]="←",[38]="↑",[39]="→",[40]="↓",[45]="Ins",[46]="Del",[220]="\\"}
  if vk>=96 and vk<=105 then return "Num "..tostring(vk-96) end
  return labels[vk] or VK_TO_FKEY[vk] or "?"
end

for i=0,9 do VK_TO_FKEY[0x60+i]="NumPad"..(({"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"})[i+1]) end

local SLOT_WIDGET={"Left","Top","Right","Bottom"}
local BINDING_GROUPS={"Ability","Consumable"}

-- Presets are a Mod Menu editing aid only. Selecting one must not mutate
-- config.ini behind the menu transaction. The compatibility patch expands
-- presets in memory; only Apply writes the resulting values.
local InitialText=readall(CONFIG_PATH) or ""
local function load_config(text)
  local ini=parse_ini(text)
  local c={Enabled=iv(ini,"General","Enabled",1),Preset=iv(ini,"General","Preset",1), HoldThresholdMs=iv(ini,"General","HoldThresholdMs",200), RemoveDefinedActionBindings=iv(ini,"General","RemoveDefinedActionBindings",1),
    ShowBothWheels=iv(ini,"General","ShowBothWheels",1),ConsumablesX=iv(ini,"Position Modifiers","ConsumablesX",40),ConsumablesY=iv(ini,"Position Modifiers","ConsumablesY",-420),AbilitiesX=iv(ini,"Position Modifiers","AbilitiesX",20),AbilitiesY=iv(ini,"Position Modifiers","AbilitiesY",40),SwapAbilitiesWithConsumables=iv(ini,"Position Modifiers","SwapAbilitiesWithConsumables",0)}
  if c.HoldThresholdMs<50 then c.HoldThresholdMs=50 elseif c.HoldThresholdMs>1000 then c.HoldThresholdMs=1000 end
  for _,group in ipairs(BINDING_GROUPS) do
    for slot=1,4 do
      local field=group..slot
      c[field]=iv(ini,"Bindings",field,0)
      c[field.."Mode"]=iv(ini,"Bindings",field.."Mode",0)
    end
  end
  c.DrawWeapon=iv(ini,"Bindings","DrawWeapon",0)
  c.DrawWeaponMode=iv(ini,"Bindings","DrawWeaponMode",0)
  return c
end
local LastConfigText=readall(CONFIG_PATH) or InitialText
local Config=load_config(LastConfigText)
local Enhanced
local PersistentInput
local Suppression
local sync_inventory_context
local RecoveryWork
local reset_world_visuals
local function request_recovery()
  if not RecoveryWork then return end
  if Config.Enabled~=0 then RecoveryWork:Request('input'); RecoveryWork:Request('inventory'); RecoveryWork:Request('hud') end
  if Config.RemoveDefinedActionBindings~=0 then RecoveryWork:Request('cleanup') end
end

-- Gameplay input classification remains owned by Unreal Enhanced Input.
local function get_live(class,predicate)
  local ok,objs=pcall(function() return FindAllOf(class) end); if not ok or not objs then return nil end
  for _,o in ipairs(objs) do if valid(o) and not fullname(o):find("Default__",1,true) and (not predicate or predicate(o)) then return o end end
end
local function ability_button(slot)
  local ok,objs=pcall(function() return FindAllOf("WBP_AA_Quickslots_Button_C") end); if not ok or not objs then return nil end
  local fallback
  for _,o in ipairs(objs) do if valid(o) and tonumber(safe(o,"TargetQuickslot"))==slot-1 and not fullname(o):find("Default__",1,true) then
    local aw=safe(o,"AbilityWidget"); if valid(aw) and fullname(o):find("/Engine/Transient.",1,true) then return o end; if valid(aw) and not fallback then fallback=o end
  end end
  return fallback
end
local function trigger_ability(slot)
  local b=ability_button(slot)
  if not valid(b) then return false,"no live ability button for slot "..slot end
  local target=fullname(b)
  local ok,e=pcall(function() b:BP_OnClicked() end)
  if not ok then return false,"BP_OnClicked failed for "..target..": "..tostring(e) end
  return true,"BP_OnClicked on "..target
end
local function consumable_widget() return get_live("WBP_HUD_Quickslots_C",function(o) return valid(safe(o,"Left")) end) end
local function bind_overlay() return get_live("WBP_Inventory_QuickslotBindOverlay_C",function(o) local ok,v=pcall(function() return o:IsActivated() end); return ok and v==true end) end
local function trigger_consumable(slot)
  local w=consumable_widget()
  local b=valid(w) and safe(w,SLOT_WIDGET[slot]) or nil
  if not valid(b) then return false,"no live consumable button for slot "..slot end
  local target=fullname(b)
  local ok,e=pcall(function() b:BP_OnClicked() end)
  if not ok then return false,"BP_OnClicked failed for "..target..": "..tostring(e) end
  return true,"BP_OnClicked on "..target
end
local function native_action(path)
  local ok,o=pcall(function() return StaticFindObject(path) end); return ok and valid(o) and o or nil
end
local function game_hud() return get_live("WBP_GameHUD_C",function(o) return valid(safe(o,"QuickslotsSwitcher")) end) end
local refresh_hud_visuals

local function unwrap(v)
  if v==nil then return nil end
  local ok,x=pcall(function() return v:get() end)
  return ok and x or v
end
local function fname_string(v)
  v=unwrap(v); if v==nil then return "" end
  local ok,x=pcall(function() return v:ToString() end)
  return ok and tostring(x) or tostring(v)
end
local function each_container(c,fn)
  if c==nil then return false end
  if type(c)=="table" then for k,v in pairs(c) do fn(k,v) end return true end
  local ok=pcall(function() c:ForEach(function(k,v) fn(k,v) end) end)
  return ok
end
-- Explicit native-action suppression allowlist. Do not infer unverified aliases.
local SuppressionTargets={
  {action="IA_Quickslot_Left",row="player_quickslot_left"},
  {action="IA_Quickslot_Top",row="player_quickslot_top"},
  {action="IA_Quickslot_Right",row="player_quickslot_right"},
  {action="IA_Quickslot_Bottom",row="player_quickslot_bottom"},
  {action="IA_DrawToggleSword",row="combat_draw_weapon"},
  {action="IA_Combat_ToggleQuickslots",row="combat_toggle_quickslots"},
  {action="IA_OW_ToggleQuickslots",row="ow_toggle_quickslots"},
}
local function action_is_defined_here(action)
  if not valid(action) then return false end
  local name=fullname(action):match("([^%.:/%s]+)$")
  for _,target in ipairs(SuppressionTargets) do if name==target.action then return true end end
  return false
end
local function mapping_name_is_defined_here(n)
  local function normalize(value) return tostring(value or ""):lower():gsub("[%s_%-]","") end
  n=normalize(n)
  for _,target in ipairs(SuppressionTargets) do
    if (target.row and n==normalize(target.row)) or n==normalize(target.action) then return true end
  end
  return false
end
local function remove_native_conflicts()
  if not Suppression then return false end
  if Config.Enabled==0 or Config.RemoveDefinedActionBindings==0 then return Suppression:Restore() end
  if not Enhanced or not valid(Enhanced.playerInput) then return false end
  local contexts={}
  each_container(safe(Enhanced.playerInput,"AppliedInputContexts"),function(k)
    local c=unwrap(k);if valid(c) then contexts[#contexts+1]=c end
  end)
  return Suppression:Apply(contexts)
end

-- Dawnwalker keeps gameplay mapping contexts applied while Pause, Game Hub and
-- dialogue own input. Bridge bindings attached directly to PawnInputComponent
-- therefore need a game-specific acceptance gate here, not in the generic bridge.
local InputGate={blockingWidgets={},dialogueActive=false,gameLayersVisible=nil}
local report_input_gate
local function object_path(o)
  if not valid(o) then return nil end
  local f=fullname(o)
  return f:match("^%S+%s+(.+)$") or f
end
local function bool_value(v)
  v=unwrap(v)
  if type(v)=="boolean" then return v end
  if type(v)=="number" then return v~=0 end
  local s=tostring(v or ""):lower()
  if s=="true" or s=="1" then return true end
  if s=="false" or s=="0" then return false end
  return nil
end
local function hook_param(context,key)
  local ok,v=pcall(function() return context and context[key] end)
  return ok and v or nil
end
local function blocks_gameplay_widget(o)
  local n=fullname(o):lower()
  local className=n:match("^(%S+)") or ""
  return className=="wbp_pausemenu_c"
      or className=="wbp_inventory_quickslotbindoverlay_c"
      or n:find("wbp_hub_",1,true)~=nil
      or n:find("/_unified/pausemenu/",1,true)~=nil
      or n:find("/_unified/gamehub/",1,true)~=nil
end
local function record_blocking_widget(o,active)
  if not valid(o) or not blocks_gameplay_widget(o) then return end
  local id=fullname(o)
  if active then InputGate.blockingWidgets[id]=true else InputGate.blockingWidgets[id]=nil end
  if report_input_gate then report_input_gate() end
end
local function sync_blocking_widgets_once()
  local active={}
  local ok,objects=pcall(function() return FindAllOf("DWActivatableWidget") end)
  if not ok or not objects then return false end
  for _,o in ipairs(objects) do
    if valid(o) and blocks_gameplay_widget(o) then
      local activated=false
      local okActive,result=pcall(function() return o:IsActivated() end)
      if okActive and result==true then active[fullname(o)]=true end
    end
  end
  InputGate.blockingWidgets=active
  return true
end
local function gameplay_input_allowed()
  if InputGate.dialogueActive or InputGate.gameLayersVisible==false then return false end
  return next(InputGate.blockingWidgets)==nil
end
local function input_gate_summary()
  local reasons={}
  if InputGate.dialogueActive then reasons[#reasons+1]="dialogue" end
  if InputGate.gameLayersVisible==false then reasons[#reasons+1]="game layers hidden" end
  for id in pairs(InputGate.blockingWidgets) do reasons[#reasons+1]=id end
  return #reasons==0 and "allowed" or table.concat(reasons,", ")
end
local LastReportedInputGate=nil
report_input_gate=function()
  local allowed=gameplay_input_allowed()
  if allowed==LastReportedInputGate then return end
  LastReportedInputGate=allowed
  log(allowed and "Gameplay shortcut callbacks enabled."
      or ("Gameplay shortcut callbacks suppressed: "..input_gate_summary()))
end
local function action_input_allowed(entry)
  return gameplay_input_allowed()
end
local function install_input_gate_hooks()
  local function hook(name,before,after)
    local ok,e=pcall(function() RegisterHook(name,before,after) end)
    if not ok then log("Input gate hook unavailable: "..name..": "..tostring(e)) end
  end
  hook("/Script/CommonUI.CommonActivatableWidget:ActivateWidget",function(Context)
    local o=unwrap(Context)
    if valid(o) and fullname(o):match("^(%S+)")=="WBP_Inventory_QuickslotBindOverlay_C" and sync_inventory_context then
      local ok,err=pcall(sync_inventory_context,o)
      if not ok then log("Inventory context preparation failed: "..tostring(err)) end
    end
  end,function(Context)
    local o=unwrap(Context)
    if valid(o) then
      record_blocking_widget(o,true)
      local class=fullname(o):match("^(%S+)")
      if blocks_gameplay_widget(o) or class=="WBP_GameHUD_C" then request_recovery() end
      if class=="WBP_Inventory_QuickslotBindOverlay_C" and sync_inventory_context then
        local ok,err=pcall(sync_inventory_context,o)
        if not ok then log("Inventory context activation failed: "..tostring(err)) end
      end
    end
  end)
  hook("/Script/CommonUI.CommonActivatableWidget:DeactivateWidget",function(Context)
    local o=unwrap(Context)
    if valid(o) then
      record_blocking_widget(o,false)
      if PersistentInput and fullname(o):match("^(%S+)")=="WBP_Inventory_QuickslotBindOverlay_C" then
        local ok,err=pcall(function() PersistentInput:DeactivateInventory() end)
        if not ok then
          log("Inventory context removal failed: "..tostring(err))
          if RecoveryWork then RecoveryWork:Request('inventory') end
        end
      end
    end
  end,function() end)
  hook("/Script/DogwoodUI.UIFrontend:SetGameLayersVisible",function(Context,bVisible)
    request_recovery()
    local visible=bool_value(bVisible)
    if visible==nil then visible=bool_value(hook_param(Context,"bVisible")) end
    if visible~=nil then InputGate.gameLayersVisible=visible; report_input_gate() end
  end,function() end)
  hook("/Script/DogwoodDialogue.DogwoodDialogueSubsystem:OnDialoguePlaybackStarted",function()
    InputGate.dialogueActive=true
    report_input_gate()
  end,function() end)
  hook("/Script/DogwoodDialogue.DogwoodDialogueSubsystem:OnDialogueFinished",function(Context,Dialogue,bKeepDialogueState)
    local keep=bool_value(bKeepDialogueState)
    if keep==nil then keep=bool_value(hook_param(Context,"bKeepDialogueState")) end
    if keep~=true then InputGate.dialogueActive=false; report_input_gate() end
  end,function() end)
  sync_blocking_widgets_once()
  report_input_gate()
end
install_input_gate_hooks()

do
  RegisterLoadMapPreHook(function()
    if PersistentInput then
      local ok,err=pcall(function() PersistentInput:CloseInventory();assert(PersistentInput:Close()) end)
      if not ok then log("Input detach before travel failed: "..tostring(err)) end
    end
    if Suppression then
      local ok,err=pcall(function() Suppression:Restore() end)
      if not ok then log("Suppression restoration before travel failed: "..tostring(err)) end
    end
    InputGate.blockingWidgets={}
    if RecoveryWork then RecoveryWork:Invalidate() end
    if Enhanced then
      Enhanced.generation=Enhanced.generation+1
      Enhanced.ready=false
      Enhanced.sub=nil; Enhanced.playerInput=nil; Enhanced.inputComponent=nil; Enhanced.drawContext=nil
    end
    if reset_world_visuals then reset_world_visuals() end
  end)
  RegisterLoadMapPostHook(function() request_recovery() end)
end

local function find_gameplay_stack()
  local ok,controllers=pcall(function() return FindAllOf("PlayerController") end)
  if not ok or not controllers then return nil,nil,nil,nil end
  for _,pc in ipairs(controllers) do
    local n=fullname(pc)
    if valid(pc) and not n:find("Default__",1,true) and n:find("BP_PlayerController_C",1,true) then
      local pawn=unwrap(safe(pc,"AcknowledgedPawn")) or unwrap(safe(pc,"Pawn"))
      local pi=unwrap(safe(pc,"PlayerInput"))
      local input=valid(pawn) and unwrap(safe(pawn,"InputComponent")) or nil
      if valid(pawn) and valid(pi) and valid(input) then return pc,pawn,pi,input end
    end
  end
  return nil,nil,nil,nil
end

Enhanced={ready=false,sub=nil,drawContext=nil,playerInput=nil,inputComponent=nil,inputComponentPath=nil,inputScope=nil,helperHandles={},actions={},generation=0,gameplayContextSignature=nil}
local function live_subsystem()
  return get_live("EnhancedInputLocalPlayerSubsystem",function(o) return fullname(o):find("DWLocalPlayer",1,true)~=nil end) or get_live("EnhancedInputLocalPlayerSubsystem")
end
local function live_player_input()
  local _,_,pi=find_gameplay_stack()
  return pi
end
local function cls(path) local ok,o=pcall(function() return StaticFindObject(path) end); return ok and valid(o) and o or nil end
local function array_num(a)
  if a==nil then return 0 end
  local ok,n=pcall(function() return a:GetArrayNum() end)
  if ok and tonumber(n) then return tonumber(n) end
  local ok2,n2=pcall(function() return #a end)
  return ok2 and (tonumber(n2) or 0) or 0
end
local function replace_only_trigger(action,trigger)
  local triggers=safe(action,"Triggers")
  if array_num(triggers)~=1 then return false,"cloned action does not contain exactly one trigger slot" end
  local replaced=false
  local ok=pcall(function()
    triggers:ForEach(function(_,entry)
      if not replaced then entry:set(trigger); replaced=true end
    end)
  end)
  if not ok or not replaced then return false,"UE4SS could not replace the cloned trigger slot" end
  return true
end
local function bridge_api()
  local bridge=rawget(_G,"UE4SSLuaEventBridge")
  if type(bridge)~="table" or type(bridge.GetCapabilities)~="function" then
    return nil,"UE4SSLuaEventBridge is not installed or did not initialize"
  end
  local ok,caps=pcall(bridge.GetCapabilities)
  if not ok or type(caps)~="table" then return nil,"UE4SSLuaEventBridge capabilities are unavailable" end
  local required={"enhanced_input","explicit_target","detailed_errors"}
  for _,name in ipairs(required) do
    if caps[name]~=true then return nil,"UE4SSLuaEventBridge capability is unavailable: "..name end
  end
  if tonumber(caps.api or 0)<4 then return nil,"UE4SSLuaEventBridge API 4 or later is required" end
  if tostring(caps.target_ue4ss_commit or "")~="97b7e501" then
    return nil,"UE4SSLuaEventBridge targets an incompatible UE4SS commit: "..tostring(caps.target_ue4ss_commit)
  end
  if type(bridge.OpenInputComponent)~="function" or type(bridge.BindAction)~="function" then
    return nil,"UE4SSLuaEventBridge explicit action API is unavailable"
  end
  return bridge,caps
end
local function retained_input_object(className,name)
  local outer=className=="InputAction" and StaticFindObject("/Engine/Transient.IMC_QuickslotsForever")
      or assert(get_live("Engine"),"Engine unavailable"):GetOuter()
  assert(valid(outer),"Transient input owner unavailable")
  assert(object_path(outer)==(className=="InputAction" and "/Engine/Transient.IMC_QuickslotsForever" or "/Engine/Transient"),
      "Unexpected persistent input owner")
  local path=object_path(outer)..(className=="InputAction" and ":" or ".")..name
  local object=StaticFindObject(path)
  if not valid(object) then
    -- RF_Transient | RF_MarkAsRootSet: bounded named objects retained for this
    -- process, including inactive inventory contexts and Lua reloads.
    object=StaticConstructObject(assert(cls("/Script/EnhancedInput."..className)),outer,FName(name),0xC0)
  end
  assert(valid(object),"Unable to retain "..name)
  return object
end
PersistentInput=dofile(scripts.."/persistent_input.lua")({
  valid=valid,path=object_path,resolve=native_action,retain=retained_input_object,name=FName,
  load_inventory=function() return ModRef:GetSharedVariable("QuickslotsForever.InventoryOwner.v1") end,
  save_inventory=function(s) ModRef:SetSharedVariable("QuickslotsForever.InventoryOwner.v1",s) end,
  same=function(a,b) return valid(a) and valid(b) and fullname(a)==fullname(b) end,
  key=function(vk) return VK_TO_FKEY[vk] end,
  each=function(c,fn) assert(each_container(c,function(i,v) fn(i,unwrap(v)) end),"Mapping access failed") end,
  bridge=function() return assert(bridge_api()) end,
  initialize_identity=function(a)
    StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):Conv_ObjectToSoftObjectReference(a)
  end,
  trigger=function(a,mode,threshold)
    local className=mode==1 and "InputTriggerHold" or "InputTriggerTap"
    local t
    each_container(a.Triggers,function(_,v)
      local candidate=unwrap(v)
      if valid(candidate) and fullname(candidate):match("^(%S+)")==className then t=candidate end
    end)
    if not valid(t) then t=StaticConstructObject(assert(cls("/Script/EnhancedInput."..className)),a,0,0x40) end
    assert(valid(t),"Trigger construction failed")
    if mode==1 then t.HoldTimeThreshold=threshold;t.bIsOneShot=true
    else t.TapReleaseTimeThreshold=threshold end
    a.Triggers={t}
  end,
  native_action=function(direction)
    return native_action("/Game/_Dawnwalker/Player/Input/Actions/Quickslots/IA_Quickslot_"..direction..".IA_Quickslot_"..direction)
  end,
  present=function(context)
    local found=false
    if valid(Enhanced.playerInput) and valid(context) then
      each_container(Enhanced.playerInput.AppliedInputContexts,function(k)
        if fullname(unwrap(k))==fullname(context) then found=true end
      end)
    end
    return found
  end,
})
Suppression=dofile(scripts.."/runtime_suppression.lua")({
  valid=valid,path=object_path,resolve=native_action,name=FName,target=action_is_defined_here,
  key=function(m) return fname_string(m.Key.KeyName) end,
  each=function(c,fn) assert(each_container(c,function(i,v) fn(i,unwrap(v)) end),"Mapping access failed") end,
  owned=function(c)
    -- Native assets live under /Game; preserve all transient mod contexts,
    -- including native-action inventory and Draw Weapon mappings.
    return PersistentInput:Owns(c) or not (object_path(c) or ""):match("^/Game/")
  end,
  load=function() return ModRef:GetSharedVariable("QuickslotsForever.SuppressionFields.v1") end,
  save=function(s) ModRef:SetSharedVariable("QuickslotsForever.SuppressionFields.v1",s) end,
  rebuild=function(c)
    local lib=StaticFindObject("/Script/EnhancedInput.Default__EnhancedInputLibrary")
    assert(valid(lib),"EnhancedInputLibrary unavailable")
    lib:RequestRebuildControlMappingsUsingContext(c,false)
  end,
})
sync_inventory_context=function(overlay)
  if Config.Enabled==0 then PersistentInput:CloseInventory();return false end
  local o=overlay or get_live("WBP_Inventory_QuickslotBindOverlay_C",function(w)
    return fullname(w):find('/Engine/Transient',1,true)~=nil
  end)
  local sub=live_subsystem()
  if valid(o) then
    if not valid(sub) then return false end
    if overlay~=nil or o:IsActivated() then return PersistentInput:OpenInventory(o,sub) end
    if not PersistentInput:AttachInventory(o,sub) then return false end
    PersistentInput:DeactivateInventory()
    return true
  end
  PersistentInput:CloseInventory()
  return true
end
local function clear_bridge_bindings()
  Enhanced.generation=Enhanced.generation+1
  local ok,closed,err=pcall(function() return PersistentInput:Close() end)
  if not ok or not closed then return false,tostring(ok and err or closed) end
  Enhanced.inputScope=nil
  Enhanced.helperHandles={}
  Enhanced.inputComponent=nil
  Enhanced.inputComponentPath=nil
  return true
end
local function bind_bridge_actions(input,sub,defs)
  local bridge,bridgeErr=bridge_api()
  if not bridge then return false,bridgeErr end
  PersistentInput:Configure(Config)
  Enhanced.inputComponent=input
  Enhanced.inputComponentPath=object_path(input)
  local generation=Enhanced.generation
  local function callback_for(binding)
    return function()
      -- Bridge callbacks run on the UE4SS update thread. Dawnwalker widget
      -- lookup, gameplay gating and BP_OnClicked dispatch must run on the
      -- Unreal game thread.
      local scheduled,scheduleErr=pcall(function()
        ExecuteInGameThread(function()
          if generation~=Enhanced.generation then
            return
          end
          if not Enhanced.ready then
            return
          end
          if not action_input_allowed(binding) then
            return
          end
          local dispatch=binding.group=="Ability" and trigger_ability or trigger_consumable
          local called,dispatched,detail=pcall(dispatch,binding.slot)
          if not called then
            log(binding.field.." dispatch exception: "..tostring(dispatched))
          elseif not dispatched then
            log(binding.field.." dispatch failed: "..tostring(detail))
          end
        end)
      end)
      -- Do not let a scheduling failure escape into the bridge dispatcher;
      -- callback errors intentionally deactivate their native subscription.
      if not scheduled then log(binding.field.." game-thread dispatch failed: "..tostring(scheduleErr)) end
    end
  end
  local bound,err=PersistentInput:Bind(input,sub,defs,callback_for)
  if not bound then return false,err end
  Enhanced.inputScope=PersistentInput
  Enhanced.actions=defs
  return true
end
local function find_loaded_action(fragment)
  local ok,objs=pcall(function() return FindAllOf("InputAction") end)
  if not ok or not objs then return nil end
  for _,action in ipairs(objs) do
    if valid(action) and fullname(action):find(fragment,1,true) then return action end
  end
end
local function make_trigger(outer,mode,continuous)
  local triggerPath=(mode==1) and "/Script/EnhancedInput.InputTriggerHold" or "/Script/EnhancedInput.InputTriggerTap"
  local triggerClass=cls(triggerPath)
  if not valid(triggerClass) then return nil,triggerPath.." class unavailable" end
  local okt,trigger=pcall(function() return StaticConstructObject(triggerClass,outer) end)
  if not okt or not valid(trigger) then return nil,"could not construct native action trigger" end
  pcall(function()
    if mode==1 then
      trigger.HoldTimeThreshold=Config.HoldThresholdMs/1000.0
      trigger.bIsOneShot=not continuous
    else
      trigger.TapReleaseTimeThreshold=Config.HoldThresholdMs/1000.0
    end
  end)
  return trigger
end
local function find_mapping_context_template()
  local ok,contexts=pcall(function() return FindAllOf("InputMappingContext") end)
  if not ok or not contexts then return nil end
  for _,context in ipairs(contexts) do
    if valid(context) and not fullname(context):find("QuickslotsForever",1,true) then
      local found=false
      each_container(safe(context,"Mappings"),function(_,mp)
        local mapping=unwrap(mp)
        if mapping and array_num(safe(mapping,"Triggers"))==1 then found=true end
      end)
      if found then return context end
    end
  end
end
local function configure_cloned_draw_context(sub,action,key,mode)
  local template=find_mapping_context_template()
  if not valid(template) then return nil,"no loaded mapping context with one reusable trigger slot" end
  local contextClass=cls("/Script/EnhancedInput.InputMappingContext")
  local ok,context=pcall(function() return StaticConstructObject(contextClass,sub,0,0,0,false,false,template) end)
  if not ok or not valid(context) then return nil,"could not clone mapping context template" end
  local chosen=nil; local removals={}
  each_container(safe(context,"Mappings"),function(_,mp)
    local mapping=unwrap(mp)
    if mapping then
      local oldAction=safe(mapping,"Action"); local oldKey=safe(mapping,"Key")
      if not chosen and array_num(safe(mapping,"Triggers"))==1 then
        chosen=mapping
      else
        removals[#removals+1]={action=oldAction,key=oldKey}
      end
    end
  end)
  if not chosen then return nil,"cloned context lost its reusable trigger slot" end
  local trigger,triggerErr=make_trigger(context,mode,false)
  if not valid(trigger) then return nil,triggerErr end
  local replaced,replaceErr=replace_only_trigger(chosen,trigger)
  if not replaced then return nil,replaceErr end
  pcall(function()
    chosen.Action=action
    chosen.Key={KeyName=FName(key)}
    chosen.PlayerMappableKeySettings=nil
    chosen.SettingBehavior=2
    local modifiers=safe(chosen,"Modifiers"); if modifiers then modifiers:Empty() end
  end)
  for _,r in ipairs(removals) do
    if valid(r.action) and r.key~=nil then pcall(function() context:UnmapKey(r.action,r.key) end) end
  end
  log("Draw Weapon mapping template: "..fullname(template))
  return context
end
local function map_native_draw(sub)
  local key=VK_TO_FKEY[Config.DrawWeapon]
  if not key then return false,"unsupported FKey for DrawWeapon" end
  local action=find_loaded_action("IA_DrawToggleSword")
  if not valid(action) then return false,"IA_DrawToggleSword is not loaded yet" end
  local context,err=configure_cloned_draw_context(sub,action,key,Config.DrawWeaponMode or 0)
  if not valid(context) then return nil,"IA_DrawToggleSword: "..tostring(err) end
  log("Draw Weapon mapped directly to native IA_DrawToggleSword on "..key.." with an Enhanced Input "..(((Config.DrawWeaponMode or 0)==1) and "Hold" or "Tap").." trigger.")
  return context
end
local ContextRegistry=dofile(scripts.."/context_registry.lua")({
  get_shared=function(key) return ModRef:GetSharedVariable(key) end,
  set_shared=function(key,value) ModRef:SetSharedVariable(key,value) end,
  path=object_path,resolve=native_action,valid=valid,
  remove=function(sub,context)
    sub:RemoveMappingContext(context,{bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false})
  end,
})
ContextRegistry:ForgetLegacy()
local function clear_old_context(sub)
  local ok,cleared,err=pcall(function() return ContextRegistry:Clear(sub) end)
  if not ok then return false,tostring(cleared) end
  return cleared,err
end
local function gameplay_context_signature(playerInput,drawContext)
  if not valid(playerInput) then return "<no-player-input>" end
  local contexts={}
  local drawName=valid(drawContext) and fullname(drawContext) or nil
  local drawPresent=false
  each_container(safe(playerInput,"AppliedInputContexts"),function(k,_)
    local context=unwrap(k)
    if valid(context) then
      local name=fullname(context)
      if name==drawName then drawPresent=true end
      if name:find("IMC_OW.",1,true) or name:find("IMC_RTCombat.",1,true) then
        contexts[#contexts+1]=name
      end
    end
  end)
  table.sort(contexts)
  return (#contexts>0 and table.concat(contexts,"|") or "<no-gameplay-routing-context>"),drawPresent
end
local function setup_enhanced_input()
  if Enhanced.ready then return true end
  local sub=live_subsystem()
  local pc,pawn,pi,input=find_gameplay_stack()
  if not valid(sub) or not valid(pc) or not valid(pawn) or not valid(pi) or not valid(input) then return false end
  local bridge,bridgeErr=bridge_api()
  if not bridge then
    if Enhanced.bridgeError~=bridgeErr then Enhanced.bridgeError=bridgeErr; log("Enhanced Input: "..bridgeErr) end
    return false
  end
  Enhanced.bridgeError=nil
  local cleared,clearErr=clear_bridge_bindings()
  if not cleared then log("Enhanced Input: "..tostring(clearErr)); return false end
  local contextCleared,contextError=clear_old_context(sub)
  if not contextCleared then log("Draw context cleanup pending: "..tostring(contextError)); return false end
  Enhanced.sub,Enhanced.playerInput,Enhanced.inputComponent=sub,pi,input
  Enhanced.inputComponentPath=object_path(input)
  local defs={}
  for _,group in ipairs(BINDING_GROUPS) do
    for slot=1,4 do
      defs[#defs+1]={group=group,slot=slot,field=group..slot}
    end
  end
  -- The mod retains named actions; only subscriptions follow the input component.
  local bridgeBound,bindErr=bind_bridge_actions(input,sub,defs)
  if not bridgeBound then
    log("Enhanced Input helper binding failed: "..tostring(bindErr))
    return false
  end
  local drawContext,drawErr=map_native_draw(sub)
  if not valid(drawContext) then
    clear_bridge_bindings()
    log("Enhanced Input: "..tostring(drawErr))
    return false
  end
  Enhanced.drawContext=drawContext
  local remembered,rememberError=pcall(function() ContextRegistry:Remember(drawContext,sub) end)
  if not remembered then
    clear_bridge_bindings()
    Enhanced.drawContext=nil
    log("Draw context registration failed: "..tostring(rememberError))
    return false
  end
  remove_native_conflicts(nil,nil)
  local options={bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false}
  local okdraw,drawAddErr=pcall(function() sub:AddMappingContext(drawContext,10001,options) end)
  if not okdraw then
    clear_bridge_bindings()
    log("AddMappingContext failed for Draw Weapon: "..tostring(drawAddErr))
    return false
  end
  pcall(function() sub:RequestRebuildControlMappings(options,1) end)
  Enhanced.gameplayContextSignature=gameplay_context_signature(pi)
  Enhanced.ready=true
  if RecoveryWork then
    RecoveryWork:AfterReady('hud')
    RecoveryWork:AfterReady('inventory')
  end
  sync_blocking_widgets_once()
  log(string.format("Enhanced Input ready on %s: %d persistent action bindings + native Draw Weapon, Tap/Hold threshold=%d ms, gameplay routing=%s.",Enhanced.inputComponentPath or "<unknown>",#Enhanced.actions,Config.HoldThresholdMs,Enhanced.gameplayContextSignature))
  return true
end
local function context_present(ctx)
  if not valid(ctx) or not valid(Enhanced.playerInput) then return false end
  local contextName=fullname(ctx)
  local present=false
  each_container(safe(Enhanced.playerInput,"AppliedInputContexts"),function(k,_)
    local key=unwrap(k)
    if valid(key) and fullname(key)==contextName then present=true end
  end)
  return present
end
local function ensure_context(ctx,priority,label,knownPresent)
  if knownPresent==true or (knownPresent==nil and context_present(ctx)) then return true end
  if not valid(ctx) or not valid(Enhanced.sub) then return false end
  local options={bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false}
  local ok,e=pcall(function() Enhanced.sub:AddMappingContext(ctx,priority,options) end)
  if not ok then log("Enhanced Input context restore failed: "..label..": "..tostring(e)); return false end
  log("Enhanced Input context restored: "..label)
  pcall(function() Enhanced.sub:RequestRebuildControlMappings(options,1) end)
  return true
end
local DisabledContextCleaned=false
local function enhanced_input_step()
      if Config.Enabled~=0 then
        DisabledContextCleaned=false
        if Enhanced.ready then
          local liveSub=live_subsystem(); local _,_,liveInput,liveComponent=find_gameplay_stack()
          local invalidReason
          if not valid(Enhanced.sub) then invalidReason="stored subsystem invalid"
          elseif not valid(Enhanced.playerInput) then invalidReason="stored PlayerInput invalid"
          elseif Enhanced.inputScope==nil then invalidReason="helper scope missing"
          elseif not valid(Enhanced.inputComponent) then invalidReason="stored input component invalid"
          elseif not valid(liveSub) then invalidReason="live subsystem unavailable"
          elseif not valid(liveInput) then invalidReason="live PlayerInput unavailable"
          elseif not valid(liveComponent) then invalidReason="live input component unavailable"
          elseif fullname(liveSub)~=fullname(Enhanced.sub) then invalidReason="subsystem changed"
          elseif fullname(liveInput)~=fullname(Enhanced.playerInput) then invalidReason="PlayerInput changed"
          elseif fullname(liveComponent)~=fullname(Enhanced.inputComponent) then invalidReason="input component changed" end
          if invalidReason then
            log("Enhanced Input lifecycle invalidated: "..invalidReason.."; rebuilding helper scope.")
            local closed=clear_bridge_bindings()
            if closed then Enhanced.ready=false end
          else
            local currentSignature,drawPresent=gameplay_context_signature(liveInput,Enhanced.drawContext)
            if currentSignature~=Enhanced.gameplayContextSignature then
              log("Enhanced Input gameplay routing changed: "..tostring(Enhanced.gameplayContextSignature).." -> "..currentSignature.."; rebuilding helper scope.")
              local closed=clear_bridge_bindings()
              if closed then Enhanced.ready=false end
            else
              ensure_context(Enhanced.drawContext,10001,"Draw Weapon",drawPresent)
              PersistentInput:EnsureGameplay(Enhanced.sub)
            end
          end
        end
        if not Enhanced.ready then setup_enhanced_input() end
      elseif not DisabledContextCleaned then
        local closed=clear_bridge_bindings()
        local sub=live_subsystem()
        if closed and valid(sub) then DisabledContextCleaned=clear_old_context(sub)==true end
      end
end

-- Runtime suppression is applied to active native contexts after lifecycle events.
-- Controls row appearance is separate; saved user bindings remain untouched.

-- HUD positioning and native key-icon display; no replacement keycap widgets.
local function parent(w) if not valid(w) then return nil end local ok,p=pcall(function() return w:GetParent() end); return ok and valid(p) and p or nil end
local function belongs(h,w)
  if not valid(h) or not valid(w) then return false end local tree=safe(h,"WidgetTree"); local root=valid(tree) and safe(tree,"RootWidget") or nil; if not valid(root) then return false end
  local rn=fullname(root); local n=w; for _=1,20 do if not valid(n) then return false end; if fullname(n)==rn then return true end; n=parent(n) end; return false
end
local NativeKeys=dofile(scripts.."/action_indicators.lua")({
  valid=valid,path=object_path,resolve=native_action,
  same=function(a,b) return valid(a) and valid(b) and fullname(a)==fullname(b) end,
  load=function() return ModRef:GetSharedVariable("QuickslotsForever.IndicatorActions.v1") end,
  save=function(s) ModRef:SetSharedVariable("QuickslotsForever.IndicatorActions.v1",s) end,
})
local function bindings_widget(owner,props)
  for _,p in ipairs(props) do local w=safe(owner,p); if valid(w) then return w end end
end
local function override_icons(ability,consumable,verbose)
  local ab=bindings_widget(ability,{"WBP_AA_Quickslots_Bindings","Bindings","QuickslotBindingsRadial"})
  local cb=bindings_widget(consumable,{"WBP_HUD_Quickslots_Bindings","Bindings","QuickslotBindingsRadial"})
  local n=0
  for slot=1,4 do
    local direction=SLOT_WIDGET[slot]
    if valid(ab) and NativeKeys:Set(safe(ab,direction),PersistentInput.actions["Ability"..slot]) then n=n+1 end
    if valid(cb) and NativeKeys:Set(safe(cb,direction),PersistentInput.actions["Consumable"..slot]) then n=n+1 end
  end
  if verbose then log("HUD key widgets updated: "..n.."/8.") end
  return n
end
local PathCache=dofile(scripts.."/object_paths.lua")
local pathEnv={find=FindAllOf,valid=valid,path=object_path,resolve=native_action,
  live=function(o) return (object_path(o) or ''):find('/Engine/Transient',1,true)~=nil end}
local RadialPaths=PathCache(pathEnv,"WBP_Combat_Focus_QuickslotBindingsRadial_C")
local PromptPaths=PathCache(pathEnv,"WBP_HUD_Quickslots_ChangePrompt_C")
local function override_skill_wheel(verbose)
  local n=0
  local ready=true
  local visited=RadialPaths:Visit(function(radial)
      for slot=1,4 do
        local entity=safe(radial,SLOT_WIDGET[slot])
        local nested=valid(entity) and safe(entity,"Button") or nil
        local button=valid(nested) and nested or entity
        if NativeKeys:Set(button,PersistentInput.actions["Ability"..slot]) then n=n+1 else ready=false end
      end
  end)
  if verbose and n>0 then log("Skill-wheel key widgets updated: "..n.." widget(s) across all live radial wheels.") end
  return visited~=false and ready
end

local function same(a,b) return valid(a) and valid(b) and fullname(a)==fullname(b) end
local WheelLayout=dofile(scripts.."/wheel_layout.lua")({valid=valid,safe=safe,unwrap=unwrap,parent=parent,same=same,fullname=fullname})
local function hide_swap_prompt(hud,ability)
  -- The live HUD exposes the native swap-wheel prompt directly. Hide the entire
  -- prompt with opacity so its icon and its key glyph disappear while the widget
  -- remains in the native hierarchy.
  local hidden=false
  local function hide(w)
    if not valid(w) then return end
    if WheelLayout:HidePrompt(w) then hidden=true end
  end
  hide(valid(hud) and safe(hud,"WBP_HUD_Quickslots_ChangePrompt") or nil)
  -- Several prompt instances can coexist during HUD reconstruction. Hiding only
  -- the instance referenced by GameHUD leaves a stale icon/control pair visible.
  PromptPaths:Visit(hide)
  -- Fallback names retained for builds where the prompt is nested differently.
  local props={"ToggleQuickSlotsButton","ToggleQuickslotsButton","SwapQuickslots","SwapQuickSlots","ToggleQuickslots"}
  local function hide_fallbacks(owner)
    for _,p in ipairs(props) do hide(valid(owner) and safe(owner,p) or nil) end
  end
  hide_fallbacks(hud)
  hide_fallbacks(ability)
  return hidden
end

local function wheel_offsets()
  if Config.SwapAbilitiesWithConsumables~=0 then
    -- The labels describe the on-screen position, not a permanently-owned widget.
    -- Once swapped, the Abilities controls own the Consumables widget position and
    -- the Consumables controls own the Abilities widget position.
    return Config.ConsumablesX,Config.ConsumablesY,Config.AbilitiesX,Config.AbilitiesY
  end
  return Config.AbilitiesX,Config.AbilitiesY,Config.ConsumablesX,Config.ConsumablesY
end
local VisualGuardArmed=false
local LastLayoutError
-- Do not hook RebelInputWidget:UpdateActionWidget. During initial UI startup,
-- UE4SS 3.0.1 can crash while marshalling that function's UObject parameter
-- before Lua is entered. Only existing lifecycle/creation refresh requests update
-- native icons; this candidate does not hook that function.
refresh_hud_visuals=function(verbose,hud)
  -- Re-read the persisted visual choice whenever the HUD is rebuilt/reset.
  -- This keeps death/load reconstruction consistent with the Mod Menu checkbox.
  local h=hud or game_hud(); if not valid(h) then if verbose then log("GUI: no live GameHUD.") end; return false end
  local s=safe(h,"QuickslotsSwitcher"); local a=safe(h,"WBP_AA_Quickslots"); local c=safe(h,"WBP_HUD_Quickslots")
  if not valid(s) or not valid(a) or not valid(c) then if verbose then log("GUI: quickslot widgets not ready.") end; return false end
  if not belongs(h,s) or not belongs(h,a) or not belongs(h,c) then if verbose then log("GUI: stale HUD tree rejected.") end; return false end
  local ax,ay,cx,cy=wheel_offsets()
  local laidOut,layoutError=WheelLayout:Update(h,s,a,c,Config.ShowBothWheels~=0,ax,ay,cx,cy)
  if not laidOut then
    if LastLayoutError~=layoutError then log("GUI layout pending: "..tostring(layoutError)); LastLayoutError=layoutError end
  else LastLayoutError=nil end
  local connected=override_icons(a,c,verbose)
  local radialReady=override_skill_wheel(verbose)
  if laidOut and Config.ShowBothWheels~=0 then hide_swap_prompt(h,a) end
  return laidOut and connected==8 and radialReady
end

local function apply_hud(hud)
  local h=hud or game_hud(); if not valid(h) then log("GUI: no live GameHUD."); return end
  local s=safe(h,"QuickslotsSwitcher"); local a=safe(h,"WBP_AA_Quickslots"); local c=safe(h,"WBP_HUD_Quickslots"); if not valid(s) or not valid(a) or not valid(c) then log("GUI: quickslot widgets not ready."); return end
  if not belongs(h,s) or not belongs(h,a) or not belongs(h,c) then log("GUI: stale HUD tree rejected."); return end
  VisualGuardArmed=true
  if not refresh_hud_visuals(false,h) then return false end
  local ax,ay,cx,cy=wheel_offsets()
  log(string.format("GUI applied: ShowBothWheels=%s, configured Abilities=(%d,%d), Consumables=(%d,%d). Persistent HUD visual guard armed.",tostring(Config.ShowBothWheels~=0),ax,ay,cx,cy))
  return true
end

local RadialRefreshPending=false
local FullVisualRefreshPending=false
local VisualEpoch=0
local function queue_radial_refresh(fullRefresh)
  if not VisualGuardArmed then return end
  FullVisualRefreshPending=FullVisualRefreshPending or fullRefresh==true
  if RadialRefreshPending then return end
  RadialRefreshPending=true
  local epoch=VisualEpoch
  ExecuteWithDelay(1,function()
    if epoch~=VisualEpoch then return end
    ExecuteInGameThread(function()
      if epoch~=VisualEpoch then return end
      RadialRefreshPending=false
      local refreshAll=FullVisualRefreshPending
      FullVisualRefreshPending=false
      if Config.Enabled~=0 and VisualGuardArmed then
        local ready
        if refreshAll then ready=refresh_hud_visuals(false) else ready=override_skill_wheel(false) end
        if not ready and RecoveryWork then RecoveryWork:Request('hud') end
      end
    end)
  end)
end

-- Creation callbacks only request work. Resolve live widgets on the game thread,
-- without retaining or mutating the possibly partial creation wrapper.
do pcall(function()
  NotifyOnNewObject("/Game/_Dawnwalker/UI/_Unified/HUD/Quickslots/WBP_HUD_Quickslots_ChangePrompt.WBP_HUD_Quickslots_ChangePrompt_C",function()
    PromptPaths:Invalidate()
    request_recovery()
    if Config.ShowBothWheels~=0 then queue_radial_refresh(true) end
  end)
  PromptPaths:EnableNotifications()
end) end

do pcall(function()
  RegisterHook("/Game/_Dawnwalker/UI/_Unified/HUD/CombatFocus/WBP_Combat_Focus_QuickslotBindingsRadial.WBP_Combat_Focus_QuickslotBindingsRadial_C:Rebuild All",function() end,function()
    RadialPaths:Invalidate()
    queue_radial_refresh()
  end)
end) end

do pcall(function()
  NotifyOnNewObject("/Game/_Dawnwalker/UI/_Unified/HUD/CombatFocus/WBP_Combat_Focus_QuickslotBindingsRadial.WBP_Combat_Focus_QuickslotBindingsRadial_C",function()
    RadialPaths:Invalidate()
    if Config.Enabled~=0 and RecoveryWork then RecoveryWork:Request('hud') end
    queue_radial_refresh()
  end)
  RadialPaths:EnableNotifications()
end) end

do
  for _,path in ipairs({
    "/Script/RebelInputDisplay.RebelInputWidget",
    "/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C",
  }) do
    pcall(NotifyOnNewObject,path,function()
      if Config.Enabled~=0 and RecoveryWork then RecoveryWork:Request('hud') end
      RadialPaths:Invalidate()
    end)
  end
  local ok,err=pcall(NotifyOnNewObject,
    "/Game/_Dawnwalker/UI/_Unified/GameHub/Inventory/WBP_Inventory_QuickslotBindOverlay.WBP_Inventory_QuickslotBindOverlay_C",
    function()
      if Config.Enabled~=0 and RecoveryWork then RecoveryWork:Request('inventory') end
    end)
  if not ok then log('Inventory overlay creation notification unavailable: '..tostring(err)) end
end

-- Hooks queue readiness work directly; there is no repeating recovery timer.
local AutoHudApplied=false
local AutoHudName=""
local function update_hud_once()
  local h=game_hud(); local n=valid(h) and fullname(h) or ""
  if n=="" then AutoHudApplied=false; AutoHudName=""; return false end
  if n~=AutoHudName then
    NativeKeys:Prune()
    AutoHudApplied=apply_hud(h)==true
    if AutoHudApplied then AutoHudName=n end
  else AutoHudApplied=refresh_hud_visuals(false,h)==true end
  return AutoHudApplied
end
reset_world_visuals=function()
  -- Keep scalar indicator restoration records if the native HUD survives travel.
  VisualEpoch=VisualEpoch+1
  RadialRefreshPending=false;FullVisualRefreshPending=false
  -- Restore before travel: some transitions keep the HUD instance alive.
  -- Forgetting a still-reparented wheel would lose the native hierarchy snapshot.
  local restored,err=WheelLayout:RestoreAll()
  if not restored then log('Wheel layout restoration before travel pending: '..tostring(err)) end
  AutoHudName=""; AutoHudApplied=false; VisualGuardArmed=false
  RadialPaths:Invalidate(); PromptPaths:Invalidate()
end
RecoveryWork=dofile(scripts.."/event_work.lua")({
  attempts=6,queue=ExecuteInGameThread,delay=ExecuteWithDelay,retry_ms=500,log=log,
  enabled=function() return true end, -- DMM master-enable events can wake recovery
  run=function(name)
    if name=='input' then enhanced_input_step(); return Config.Enabled==0 or Enhanced.ready end
    if name=='inventory' then if Config.Enabled==0 then return true end;return sync_inventory_context() end
    if name=='hud' then return Config.Enabled==0 or update_hud_once() end
    if name=='cleanup' then return remove_native_conflicts(nil,nil) end
  end,
})
local function recovery_hook(path,callback)
  local ok,err=pcall(RegisterHook,path,function() end,callback)
  if not ok then log("Recovery hook unavailable: "..path..": "..tostring(err)) end
end
do
  recovery_hook('/Script/Engine.PlayerController:ClientRestart',request_recovery)
  recovery_hook('/Script/Engine.PlayerController:ClientRetryClientRestart',request_recovery)
  recovery_hook('/Script/Engine.Controller:OnRep_Pawn',request_recovery)
  recovery_hook('/Script/RebelInput.RebelInputMappingSubsystem:ApplyPendingKeyboardMappings',request_recovery)
  -- Suppress a newly applied native context before it enters the active set.
  -- RequestRebuildControlMappingsUsingContext never calls AddMappingContext.
  local okSuppressHook,suppressHookError=pcall(RegisterHook,
    '/Script/EnhancedInput.EnhancedInputSubsystemInterface:AddMappingContext',
    function(_,mappingContext)
      if Config.Enabled==0 or Config.RemoveDefinedActionBindings==0 or not Suppression then return end
      local context=unwrap(mappingContext)
      if valid(context) then
        local ok,err=pcall(function() Suppression:Apply({context}) end)
        if not ok then log('Context suppression failed: '..tostring(err)) end
      end
    end,function() end)
  if not okSuppressHook then log('Pre-activation suppression hook unavailable: '..tostring(suppressHookError)) end
  for _,name in ipairs({'AddMappingContext','RemoveMappingContext','ClearAllMappings'}) do
    recovery_hook('/Script/EnhancedInput.EnhancedInputSubsystemInterface:'..name,function()
      if Config.Enabled~=0 then RecoveryWork:Request('input') end
      if Config.RemoveDefinedActionBindings~=0 then RecoveryWork:Request('cleanup') end
    end)
  end
  for _,class in ipairs({'/Script/Engine.PlayerController','/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem',
      '/Script/EnhancedInput.EnhancedInputComponent','/Script/EnhancedInput.InputAction',
      '/Script/EnhancedInput.InputMappingContext'}) do
    local ok,err=pcall(NotifyOnNewObject,class,request_recovery)
    if not ok then log('Recovery creation notification unavailable: '..class..': '..tostring(err)) end
  end
  request_recovery()
end

-- Mod Menu Apply owns configuration changes. Subscribe once; master toggles
-- run in place so neither persistent actions nor the subscription are replaced.
local function reconfigure_from_text(now)
  local previous=Config
  local updated=load_config(now)
  if updated.Enabled~=previous.Enabled and updated.Enabled==0 then
    if NativeKeys then
      local restored,why=NativeKeys:RestoreAll()
      if not restored then log("Native display restoration pending: "..tostring(why)); return false end
    end
    local restored,restoreError=WheelLayout:RestoreAll()
    if not restored then log("GUI restoration pending before disable: "..tostring(restoreError)); return false end
    local sub=valid(Enhanced.sub) and Enhanced.sub or live_subsystem()
    if not clear_bridge_bindings() then return false end
    Enhanced.ready=false
    if not clear_old_context(sub) then return false end
    PersistentInput:CloseInventory()
    Suppression:Restore()
    if RecoveryWork then RecoveryWork:Invalidate() end
    reset_world_visuals()
  end

  Config=updated
  LastConfigText=now
  if updated.RemoveDefinedActionBindings~=previous.RemoveDefinedActionBindings then
    remove_native_conflicts()
  end
  local inputChanged=updated.Enabled~=previous.Enabled or updated.HoldThresholdMs~=previous.HoldThresholdMs
      or updated.DrawWeapon~=previous.DrawWeapon or updated.DrawWeaponMode~=previous.DrawWeaponMode
  for _,group in ipairs(BINDING_GROUPS) do for slot=1,4 do
    local field=group..slot
    if updated[field]~=previous[field] or updated[field.."Mode"]~=previous[field.."Mode"] then inputChanged=true end
  end end
  if inputChanged and Enhanced.ready then
    local sub=valid(Enhanced.sub) and Enhanced.sub or live_subsystem()
    local closed=clear_bridge_bindings()
    Enhanced.ready=false
    if closed then
      if valid(sub) then clear_old_context(sub) end
      Enhanced.drawContext=nil
      Enhanced.actions={}
    else
      log("Committed config change is waiting for helper cleanup before input can be rebuilt.")
    end
  end
  request_recovery()
  log("Applied committed config changes; input rebuild="..tostring(inputChanged)..".")
  return true
end
local notificationOk,notificationError=pcall(function()
  local api=dofile(scripts.."/dmm_api.lua")
  dofile(scripts.."/config_notifications.lua")({
    subscribe=api.subscribe,queue=ExecuteInGameThread,log=log,
    read=function() return readall(CONFIG_PATH) end,
    current=function() return LastConfigText end,
    apply=reconfigure_from_text,
  })
end)
if not notificationOk then log("DMM Apply subscription unavailable: "..tostring(notificationError)) end
log("Loaded v"..VERSION..(Config.Enabled~=0 and ". Auto-initialization is deferred until the local player/HUD are live." or ". Disabled in Mod Menu; gameplay/HUD initialization skipped."))
