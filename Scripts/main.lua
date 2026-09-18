-- QuickslotsForever v0.3.33
-- UE4SS Lua mod for The Blood of Dawnwalker.
-- Gameplay objects are resolved lazily. A one-time activatable-widget snapshot
-- seeds the input gate so reloading this mod inside an open menu is safe.

local TAG="[QuickslotsForever]"
local VERSION="0.3.33"

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
  local mouse={[1]="Mouse 1",[2]="Mouse 2",[4]="Mouse 3",[5]="Mouse 4",[6]="Mouse 5"}
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
  local c={Enabled=iv(ini,"General","Enabled",1),Preset=iv(ini,"General","Preset",1), HoldThresholdMs=iv(ini,"General","HoldThresholdMs",200), RemoveDefinedActionBindings=iv(ini,"General","RemoveDefinedActionBindings",0),
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
  local ov=bind_overlay()
  if valid(ov) then
    local target=fullname(ov)
    local ok,e=pcall(function() ov:BindItemToQuickslot(slot-1) end)
    if not ok then return false,"BindItemToQuickslot failed for "..target..": "..tostring(e) end
    return true,"BindItemToQuickslot("..tostring(slot-1)..") on "..target
  end
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
local function input_settings(sub)
  -- Resolve settings from the active local-player subsystem first. FindAllOf
  -- can return an initialized-looking RebelEnhancedInputUserSettings object
  -- that is not the profile actually used by this local player.
  local activeSub=valid(sub) and sub or (Enhanced and valid(Enhanced.sub) and Enhanced.sub or nil)
  if valid(activeSub) then
    local ok,s=pcall(function() return activeSub:GetUserSettings() end)
    if ok and valid(s) then return s,"local-player subsystem" end
  end
  local ok,objs=pcall(function() return FindAllOf("RebelEnhancedInputUserSettings") end)
  if not ok or not objs then return nil,"FindAllOf unavailable" end
  for _,o in ipairs(objs) do if valid(o) and fullname(o):find("/Engine/Transient.",1,true) and not fullname(o):find("Default__",1,true) then return o,"transient fallback" end end
  return nil,"no live user settings"
end
local function collect_mappings(profile)
  local result={}; local ok,rows=pcall(function() return profile:GetPlayerMappingRows() end); if not ok or rows==nil then return result,false end
  local scanned=each_container(rows,function(rowName,rp)
    local row=unwrap(rp); local mappings=row and safe(row,"Mappings") or nil
    each_container(mappings,function(_,mp)
      local m=unwrap(mp); if m then
        -- The TMap row key is authoritative. Some game builds expose a
        -- duplicated MappingName field as an empty/None FName.
        local name=safe(m,"MappingName")
        local nameText=fname_string(name):lower()
        if name==nil or nameText=="" or nameText=="none" then name=unwrap(rowName) end
        result[#result+1]={
          MappingName=name,
          Slot=safe(m,"Slot"),
          CurrentKey=safe(m,"CurrentKey"),
          HardwareDeviceId=safe(m,"HardwareDeviceId"),
          AssociatedInputAction=safe(m,"AssociatedInputAction")
        }
      end
    end)
  end)
  return result,scanned
end
local function mapping_key_name(m)
  local k=m and m.CurrentKey; if k==nil then return "" end
  return fname_string(k.KeyName)
end
local function mapping_name(m) return fname_string(m and m.MappingName) end
local function action_is_defined_here(action)
  if not valid(action) then return false end
  local n=fullname(action)
  return n:find("IA_Quickslot_Left",1,true)
      or n:find("IA_Quickslot_Top",1,true)
      or n:find("IA_Quickslot_Right",1,true)
      or n:find("IA_Quickslot_Bottom",1,true)
      or n:find("IA_DrawToggleSword",1,true)
      or n:find("IA_Combat_ToggleQuickslots",1,true)
      or n:find("IA_OW_ToggleQuickslots",1,true)
end
local function mapping_name_is_defined_here(n)
  n=tostring(n or ""):lower():gsub("[%s_%-]","")
  local allowed={
    playerquickslotleft=true,playerquickslottop=true,playerquickslotright=true,playerquickslotbottom=true,
    combatdrawweapon=true,combattogglequickslots=true,owtogglequickslots=true,
    iaquickslotleft=true,iaquickslottop=true,iaquickslotright=true,iaquickslotbottom=true,
    iadrawtogglesword=true,iacombattogglequickslots=true,iaowtogglequickslots=true,
  }
  return allowed[n]==true
end
local function active_contexts(pi)
  local out={}; local map=valid(pi) and safe(pi,"AppliedInputContexts") or nil
  each_container(map,function(k,_)
    local c=unwrap(k); if valid(c) then out[#out+1]=c end
  end)
  return out
end
local function target_contexts(pi)
  local out,seen={},{}
  local function add(ctx)
    if not valid(ctx) then return end
    local n=fullname(ctx); if seen[n] then return end
    local targets={}; local maps=safe(ctx,"Mappings")
    each_container(maps,function(_,mp)
      local m=unwrap(mp); local action=m and safe(m,"Action") or nil
      if valid(action) and action_is_defined_here(action) then targets[#targets+1]=fullname(action) end
    end)
    if #targets>0 then seen[n]=true; out[#out+1]={context=ctx,name=n,targets=targets} end
  end
  for _,ctx in ipairs(active_contexts(pi)) do add(ctx) end
  local ok,objs=pcall(function() return FindAllOf("InputMappingContext") end)
  if ok and objs then for _,ctx in ipairs(objs) do add(ctx) end end
  return out
end
local function mapping_key(m)
  local k=m and safe(m,"Key"); if not k then return "" end
  return fname_string(safe(k,"KeyName"))
end
local PersistentCleanupDone=false
local PersistentCleanupAttempts=0
local PersistentCleanupStage=""
local PersistentCleanupSettingsName=""
local RegisteredNativeContexts={}
local ReportedControlTargets={}
local RebelCleanupObjectName=""
local function cleanup_stage(s)
  if s~=PersistentCleanupStage then PersistentCleanupStage=s; log("Persistent controls cleanup: "..s) end
end
local function register_native_contexts_with_settings(settings,pi)
  local added=0
  for _,entry in ipairs(target_contexts(pi)) do
    local ctx=entry.context
    local n=fullname(ctx)
    for _,actionName in ipairs(entry.targets) do
      local reportKey=n.."|"..actionName
      if not ReportedControlTargets[reportKey] then
        ReportedControlTargets[reportKey]=true
        log("Controls removal target: "..actionName.." in "..n)
      end
    end
    if not RegisteredNativeContexts[n] then
      local ok,result=pcall(function() return settings:RegisterInputMappingContext(ctx) end)
      if ok and result~=false then RegisteredNativeContexts[n]=true; added=added+1
      elseif not ok then log("Could not register native mapping context "..n..": "..tostring(result)) end
    end
  end
  return added
end
local function mapping_has_current_key(m)
  local n=mapping_key_name(m):lower()
  return n~="" and n~="none" and n~="invalid"
end
local function make_unmap_args(m,profileId)
  local args={MappingName=m.MappingName,Slot=m.Slot,bDeferOnSettingsChangedBroadcast=true}
  if m.HardwareDeviceId~=nil then args.HardwareDeviceId=m.HardwareDeviceId end
  if profileId~=nil then args.ProfileId=profileId end
  return args
end
local function remove_persistent_defined_action_bindings(sub,pi)
  if Config.RemoveDefinedActionBindings==0 then return false end
  PersistentCleanupAttempts=PersistentCleanupAttempts+1
  local settings,source=input_settings(sub); if not valid(settings) then cleanup_stage(source or "user settings unavailable"); return false end
  local settingsName=fullname(settings)
  if settingsName~=PersistentCleanupSettingsName then
    PersistentCleanupSettingsName=settingsName
    PersistentCleanupDone=false
    RegisteredNativeContexts={}
    cleanup_stage("using "..tostring(source).." object "..settingsName)
  end
  local registered=register_native_contexts_with_settings(settings,pi)
  if registered>0 then PersistentCleanupDone=false end
  if PersistentCleanupDone then return true end
  local okp,profile=pcall(function() return settings:GetCurrentKeyProfile() end)
  if not okp or not valid(profile) then cleanup_stage("current key profile unavailable via "..tostring(source)); return false end
  local okid,profileId=pcall(function() return settings:GetCurrentKeyProfileIdentifier() end)
  if not okid then profileId=nil end

  local mappings,scanned=collect_mappings(profile)
  if not scanned then cleanup_stage("player mapping rows unavailable via "..tostring(source)); return false end
  if #mappings==0 then
    cleanup_stage(string.format("profile has zero player-mappable rows after registering %d active native context(s)",registered))
    return false
  end
  cleanup_stage(string.format("scanning %d player mapping(s) via %s",#mappings,tostring(source)))
  local matched,attempted=0,0
  for _,m in ipairs(mappings) do
    local action=unwrap(m.AssociatedInputAction)
    local targeted=(valid(action) and action_is_defined_here(action)) or mapping_name_is_defined_here(mapping_name(m))
    if targeted then
      matched=matched+1
      if mapping_has_current_key(m) then
        attempted=attempted+1
        local ok,e=pcall(function() settings:UnMapPlayerKey(make_unmap_args(m,profileId),{}) end)
        if not ok then log("Persistent unmap failed for "..mapping_name(m)..": "..tostring(e)) end
      end
    end
  end
  if attempted>0 then
    pcall(function() settings:ApplySettings() end)
    -- AsyncSaveSettings is the stock Enhanced Input persistence API. Keep the
    -- subclass-specific synchronous name as a compatibility fallback.
    local saved=pcall(function() settings:AsyncSaveSettings() end)
    if not saved then pcall(function() settings:SaveSettings() end) end
  end

  -- Do not declare success merely because the reflected call did not throw.
  -- Re-read the profile so the standard Controls screen and this guard agree.
  local currentProfile=profile
  local okcurrent,p=pcall(function() return settings:GetCurrentKeyProfile() end)
  if okcurrent and valid(p) then currentProfile=p end
  local after,afterScanned=collect_mappings(currentProfile)
  local remaining=0
  if afterScanned then
    for _,m in ipairs(after) do
      local action=unwrap(m.AssociatedInputAction)
      local targeted=(valid(action) and action_is_defined_here(action)) or mapping_name_is_defined_here(mapping_name(m))
      if targeted and mapping_has_current_key(m) then remaining=remaining+1 end
    end
  end
  PersistentCleanupDone=afterScanned and matched>0 and remaining==0
  if PersistentCleanupDone then
    log(string.format("Persistent controls cleanup verified: %d targeted mapping(s), none still bound.",matched))
  elseif attempted>0 or (PersistentCleanupAttempts==1 and matched==0) then
    log(string.format("Persistent controls cleanup pending: matched=%d, attempted=%d, remaining=%d.",matched,attempted,remaining))
  end
  return PersistentCleanupDone
end

local function mapping_settings_name(mapping,action)
  local settings=safe(mapping,"PlayerMappableKeySettings")
  if not valid(settings) and valid(action) then settings=safe(action,"PlayerMappableKeySettings") end
  if not valid(settings) then return "" end
  return fname_string(safe(settings,"Name"))
end
local function rebel_target_names(system)
  local names={}
  local function add_name(name)
    name=fname_string(name)
    if name~="" and name:lower()~="none" and mapping_name_is_defined_here(name) then names[name:lower()]=name end
  end
  local contexts=valid(system) and safe(system,"RebindableContexts") or nil
  each_container(contexts,function(_,cp)
    local context=unwrap(cp)
    each_container(valid(context) and safe(context,"Mappings") or nil,function(_,mp)
      local mapping=unwrap(mp); local action=mapping and safe(mapping,"Action") or nil
      if valid(action) and action_is_defined_here(action) then
        add_name(mapping_settings_name(mapping,action))
        local actionName=fullname(action):match("%.([^%.:]+)$")
        add_name(actionName)
      end
    end)
  end)
  -- The dump proves that some settings contexts are loaded before gameplay but are
  -- not necessarily present in AppliedInputContexts. Scan those assets as well.
  for _,entry in ipairs(target_contexts(nil)) do
    each_container(safe(entry.context,"Mappings"),function(_,mp)
      local mapping=unwrap(mp); local action=mapping and safe(mapping,"Action") or nil
      if valid(action) and action_is_defined_here(action) then add_name(mapping_settings_name(mapping,action)) end
    end)
  end
  return names
end
local function set_map_value(ref,value)
  local ok=pcall(function() ref:set(value) end)
  return ok
end
local CanonicalRebelRows={
  "player_quickslot_left","player_quickslot_top","player_quickslot_right","player_quickslot_bottom",
  "combat_draw_weapon","combat_toggle_quickslots","ow_toggle_quickslots"
}
local DisplayUnboundNames={}
for _,n in ipairs(CanonicalRebelRows) do DisplayUnboundNames[n]=true end
local function install_controls_display_hook()
  local ok,err=pcall(function()
    RegisterHook("/Script/RebelInputDisplay.RebelInputDisplayBlueprintFunctionLibrary:GetKeyFromBindingName",function(Context)
      local name=fname_string(Context and (Context.InName or Context["InName"])):lower()
      if not DisplayUnboundNames[name] then return end
      local rv=Context and (Context.ReturnValue or Context["ReturnValue"])
      if rv and rv.set then
        rv:set({KeyboardKey={KeyName=FName("None")},GamepadKey={KeyName=FName("None")}})
        log("Controls display override: "..name.." -> None")
      end
    end)
  end)
  if not ok then log("Controls display hook unavailable: "..tostring(err)) end
end
if Config.RemoveDefinedActionBindings~=0 then install_controls_display_hook() end
local function clear_rebel_map(map,targetNames,presetValues,ensureCanonical)
  local matched,changed=0,0
  if map==nil then return matched,changed end
  local seen={}
  pcall(function()
    map:ForEach(function(k,v)
      local name=fname_string(k)
      if targetNames[name:lower()] or mapping_name_is_defined_here(name) then
        seen[name:lower()]=true
        matched=matched+1
        local replacement=presetValues and {Key={KeyName=FName("None")}} or {KeyName=FName("None")}
        if set_map_value(v,replacement) then changed=changed+1 end
        if not ReportedControlTargets["rebel|"..name] then
          ReportedControlTargets["rebel|"..name]=true
          log("Controls removal target: "..name.." in RebelInputMappingSubsystem")
        end
      end
    end)
  end)
  -- Default rows may not exist in SavedKeyboardBindings. Add an explicit
  -- None override so GetInputForMapping resolves them as unbound.
  if ensureCanonical then
    for _,name in ipairs(CanonicalRebelRows) do
      if targetNames[name:lower()] and not seen[name:lower()] then
        local replacement={KeyName=FName("None")}
        local ok=pcall(function() map:Add(FName(name),replacement) end)
        if ok then matched=matched+1; changed=changed+1; seen[name]=true end
      end
    end
  end
  return matched,changed
end
local function rebel_key_name(system,name)
  -- The Controls widgets resolve pending/current values, not just the
  -- immutable default preset. Include pending state when verifying.
  local ok,mapped=pcall(function() return system:GetInputForMapping(FName(name),true) end)
  if not ok or mapped==nil then return "<query failed>" end
  local key=safe(mapped,"KeyboardKey")
  return fname_string(key and safe(key,"KeyName"))
end
local function remove_rebel_defined_action_bindings()
  local system=get_live("RebelInputMappingSubsystem")
  if not valid(system) then cleanup_stage("RebelInputMappingSubsystem unavailable"); return false end
  local systemName=fullname(system)
  if systemName~=RebelCleanupObjectName then
    RebelCleanupObjectName=systemName; PersistentCleanupDone=false
    cleanup_stage("using game Controls source "..systemName)
  end
  local names=rebel_target_names(system)
  local nameCount=0; for _ in pairs(names) do nameCount=nameCount+1 end
  if nameCount==0 then cleanup_stage("no targeted names found in rebindable settings contexts"); return false end

  -- The Controls screen can write a targeted binding again after our first
  -- successful cleanup. Verify the resolved values on every watchdog pass
  -- instead of treating the first success as permanent.
  if PersistentCleanupDone then
    local rebound=false
    for _,name in pairs(names) do
      local key=rebel_key_name(system,name):lower()
      if key~="" and key~="none" and key~="invalid" then rebound=true; break end
    end
    if not rebound then return true end
    PersistentCleanupDone=false
    cleanup_stage("targeted native binding changed; cleaning it again")
  end

  local save=safe(system,"PlayerMappingSave")
  local preset=safe(system,"DefaultKeyboardPreset")
  local saveMatched,saveChanged=clear_rebel_map(valid(save) and safe(save,"SavedKeyboardBindings") or nil,names,false,true)
  local presetMatched,presetChanged=clear_rebel_map(valid(preset) and safe(preset,"PresetMapping") or nil,names,true)

  -- DefaultKeyboardPreset is not necessarily the preset currently selected by
  -- the Controls screen. Its resolver uses LoadedInputPresets, so clear the
  -- loaded keyboard preset objects as well. This is deliberately limited to
  -- preset maps; live Enhanced Input contexts are never edited here.
  local loadedMatched,loadedChanged=0,0
  each_container(safe(system,"LoadedInputPresets"),function(_,entry)
    local loaded=unwrap(entry)
    if valid(loaded) then
      local m,c=clear_rebel_map(safe(loaded,"PresetMapping"),names,true)
      loadedMatched=loadedMatched+m; loadedChanged=loadedChanged+c
    end
  end)
  pcall(function() system:ApplyPendingKeyboardMappings() end)

  local remaining=0
  for _,name in pairs(names) do
    local key=rebel_key_name(system,name):lower()
    if key~="" and key~="none" and key~="invalid" then
      remaining=remaining+1
      log("Controls remaining binding: "..name.." = "..rebel_key_name(system,name))
    end
  end
  PersistentCleanupDone=(presetMatched+saveMatched+loadedMatched)>0 and remaining==0
  if PersistentCleanupDone then
    log(string.format("Controls cleanup verified through RebelInputMappingSubsystem: targets=%d, default=%d/%d, loaded=%d/%d, saved=%d/%d, none still bound.",nameCount,presetChanged,presetMatched,loadedChanged,loadedMatched,saveChanged,saveMatched))
  else
    cleanup_stage(string.format("Rebel Controls cleanup pending: names=%d, default=%d/%d, loaded=%d/%d, saved=%d/%d, remaining=%d",nameCount,presetChanged,presetMatched,loadedChanged,loadedMatched,saveChanged,saveMatched,remaining))
  end
  return PersistentCleanupDone
end

local function remove_native_conflicts(sub,pi)
  if Config.RemoveDefinedActionBindings==0 then return false end
  -- Dawnwalker's Controls page resolves keys through RebelInputMappingSubsystem,
  -- not directly through EnhancedInputUserSettings. Never fall back to editing
  -- live Enhanced Input contexts: doing so can remove mappings used by this
  -- mod's own high-priority context when the menu-side cleanup is unresolved.
  return remove_rebel_defined_action_bindings()
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
  if gameplay_input_allowed() then return true end
  -- Consumable shortcuts remain intentionally usable while the inventory's
  -- quickslot assignment overlay is active; that is configuration, not gameplay.
  return entry and entry.field and entry.field:find("Consumable",1,true)==1 and valid(bind_overlay())
end
local function install_input_gate_hooks()
  local function hook(name,before,after)
    local ok,e=pcall(function() RegisterHook(name,before,after) end)
    if not ok then log("Input gate hook unavailable: "..name..": "..tostring(e)) end
  end
  hook("/Script/CommonUI.CommonActivatableWidget:ActivateWidget",function() end,function(Context)
    local o=unwrap(Context)
    if valid(o) then record_blocking_widget(o,true) end
  end)
  hook("/Script/CommonUI.CommonActivatableWidget:DeactivateWidget",function(Context)
    local o=unwrap(Context)
    if valid(o) then record_blocking_widget(o,false) end
  end,function() end)
  hook("/Script/DogwoodUI.UIFrontend:SetGameLayersVisible",function(Context,bVisible)
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
if Config.Enabled~=0 then install_input_gate_hooks() end

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
  local required={"enhanced_input","explicit_target","helpers","dynamic_input","trigger_tap","trigger_hold","detailed_errors"}
  for _,name in ipairs(required) do
    if caps[name]~=true then return nil,"UE4SSLuaEventBridge capability is unavailable: "..name end
  end
  if tonumber(caps.api or 0)<4 then return nil,"UE4SSLuaEventBridge API 4 or later is required" end
  if tostring(caps.target_ue4ss_commit or "")~="97b7e501" then
    return nil,"UE4SSLuaEventBridge targets an incompatible UE4SS commit: "..tostring(caps.target_ue4ss_commit)
  end
  if type(bridge.Helpers)~="table" or type(bridge.Helpers.OpenInput)~="function"
      or type(bridge.Helpers.Trigger)~="table" then
    return nil,"UE4SSLuaEventBridge OpenInput helpers are unavailable"
  end
  return bridge,caps
end
local function clear_bridge_bindings()
  Enhanced.generation=Enhanced.generation+1
  if Enhanced.inputScope then
    local ok,closed,err=pcall(function() return Enhanced.inputScope:Close() end)
    if not ok or closed~=true then
      local message
      if not ok then
        message="Close raised a Lua error: "..tostring(closed)
      else
        message="Close returned failure: "..tostring(err or "no error detail")
      end
      log("Enhanced Input helper cleanup pending: "..message)
      return false,message
    end
  end
  Enhanced.inputScope=nil
  Enhanced.helperHandles={}
  Enhanced.inputComponent=nil
  Enhanced.inputComponentPath=nil
  return true
end
local function bind_bridge_actions(input,sub,defs)
  local bridge,bridgeErr=bridge_api()
  if not bridge then return false,bridgeErr end
  local componentPath=object_path(input)
  if not componentPath then return false,"could not derive gameplay PawnInputComponent path" end
  local subsystemPath=object_path(sub)
  if not subsystemPath then return false,"could not derive Enhanced Input subsystem path" end
  local okOpen,scope,openErr=pcall(bridge.Helpers.OpenInput,{
    component_path=componentPath,
    subsystem_path=subsystemPath,
    mapping_priority=10000,
    debug=false,
  })
  if not okOpen then return false,"OpenInput raised a Lua error: "..tostring(scope) end
  if scope==nil then return false,"OpenInput returned failure: "..tostring(openErr or "no error detail") end
  Enhanced.inputScope=scope
  Enhanced.inputComponent=input
  Enhanced.inputComponentPath=componentPath
  local generation=Enhanced.generation
  local Trigger=bridge.Helpers.Trigger
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
  for _,entry in ipairs(defs) do
    local key=VK_TO_FKEY[Config[entry.field]]
    if not key then clear_bridge_bindings(); return false,"unsupported FKey for "..entry.field end
    entry.mode=Config[entry.field.."Mode"] or 0
    local trigger=entry.mode==1 and Trigger.Hold or Trigger.Tap
    local options={
      threshold_seconds=Config.HoldThresholdMs/1000.0,
      -- Tap and Hold intentionally share keys in several presets. The bridge
      -- helper documents non-consuming generated actions as the mode that lets
      -- both mappings be evaluated without suppressing one another.
      consume_input=false,
      trigger_when_paused=false,
    }
    if entry.mode==1 then options.one_shot=true end
    local ok,handle,err=pcall(function()
      return scope:Bind(key,trigger,callback_for(entry),options)
    end)
    if not ok then
      clear_bridge_bindings()
      return false,entry.field.." Bind raised a Lua error: "..tostring(handle)
    end
    if handle==nil then
      clear_bridge_bindings()
      return false,entry.field.." Bind returned failure: "..tostring(err or "no error detail")
    end
    Enhanced.helperHandles[#Enhanced.helperHandles+1]=handle
  end
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
    chosen.SettingBehavior=0
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
local function gameplay_context_signature(playerInput)
  if not valid(playerInput) then return "<no-player-input>" end
  local contexts={}
  each_container(safe(playerInput,"AppliedInputContexts"),function(k,_)
    local context=unwrap(k)
    if valid(context) then
      local name=fullname(context)
      if name:find("IMC_OW.",1,true) or name:find("IMC_RTCombat.",1,true) then
        contexts[#contexts+1]=name
      end
    end
  end)
  table.sort(contexts)
  return #contexts>0 and table.concat(contexts,"|") or "<no-gameplay-routing-context>"
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
  -- OpenInput owns one private transient action/context per binding and rolls
  -- back partial creation on failure. QuickslotsForever retains target discovery,
  -- lifecycle, gameplay gating and Dawnwalker dispatch policy.
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
  sync_blocking_widgets_once()
  log(string.format("Enhanced Input ready on %s: %d OpenInput helper bindings + native Draw Weapon, Tap/Hold threshold=%d ms, gameplay routing=%s.",Enhanced.inputComponentPath or "<unknown>",#Enhanced.actions,Config.HoldThresholdMs,Enhanced.gameplayContextSignature))
  return true
end
local function context_present(ctx)
  if not valid(ctx) or not valid(Enhanced.playerInput) then return false end
  local present=false
  each_container(safe(Enhanced.playerInput,"AppliedInputContexts"),function(k,_)
    local key=unwrap(k)
    if valid(key) and fullname(key)==fullname(ctx) then present=true end
  end)
  return present
end
local function ensure_context(ctx,priority,label)
  if context_present(ctx) then return true end
  if not valid(ctx) or not valid(Enhanced.sub) then return false end
  local options={bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false}
  local ok,e=pcall(function() Enhanced.sub:AddMappingContext(ctx,priority,options) end)
  if not ok then log("Enhanced Input context restore failed: "..label..": "..tostring(e)); return false end
  log("Enhanced Input context restored: "..label)
  pcall(function() Enhanced.sub:RequestRebuildControlMappings(options,1) end)
  return true
end
local DisabledContextCleaned=false
local function enhanced_init_loop()
  ExecuteWithDelay(750,function()
    ExecuteInGameThread(function()
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
            local currentSignature=gameplay_context_signature(liveInput)
            if currentSignature~=Enhanced.gameplayContextSignature then
              log("Enhanced Input gameplay routing changed: "..tostring(Enhanced.gameplayContextSignature).." -> "..currentSignature.."; rebuilding helper scope.")
              local closed=clear_bridge_bindings()
              if closed then Enhanced.ready=false end
            else
              ensure_context(Enhanced.drawContext,10001,"Draw Weapon")
            end
          end
        end
        if not Enhanced.ready then setup_enhanced_input() end
      elseif not DisabledContextCleaned then
        local closed=clear_bridge_bindings()
        local sub=live_subsystem()
        if closed and valid(sub) then DisabledContextCleaned=clear_old_context(sub)==true end
      end
      enhanced_init_loop()
    end)
  end)
end
if Config.Enabled~=0 then enhanced_init_loop() end

-- Controls settings exist at the main menu and do not depend on a gameplay pawn,
-- gameplay world, DogwoodPlayerInput, or EnhancedInputLocalPlayerSubsystem. When
-- optional native cleanup is enabled, wait for the game's mapping subsystem.
local function controls_cleanup_watch()
  ExecuteWithDelay(1500,function()
    ExecuteInGameThread(function()
      remove_native_conflicts(nil,nil)
      controls_cleanup_watch()
    end)
  end)
end
if Config.RemoveDefinedActionBindings~=0 then controls_cleanup_watch() end

-- HUD positioning + key-icon display. Native hold override is deliberately disabled
-- because this HUD renders it as a gray square rather than the desired underline.
local function parent(w) if not valid(w) then return nil end local ok,p=pcall(function() return w:GetParent() end); return ok and valid(p) and p or nil end
local function belongs(h,w)
  if not valid(h) or not valid(w) then return false end local tree=safe(h,"WidgetTree"); local root=valid(tree) and safe(tree,"RootWidget") or nil; if not valid(root) then return false end
  local rn=fullname(root); local n=w; for _=1,20 do if not valid(n) then return false end; if fullname(n)==rn then return true end; n=parent(n) end; return false
end
local KeyVisuals={}
local function make_widget(classPath,tree)
  local c=cls(classPath); if not valid(c) then return nil end
  local ok,o=pcall(function() return StaticConstructObject(c,tree) end)
  return ok and valid(o) and o or nil
end
local function ensure_key_visual(w,vk,hold)
  local id=fullname(w); local rec=KeyVisuals[id]
  if rec and (not valid(rec.box) or not valid(rec.text) or not valid(rec.line)) then KeyVisuals[id]=nil; rec=nil end
  if not rec then
    local overlay=parent(w)
    local tree=nil
    if valid(overlay) then local ok,o=pcall(function() return overlay:GetOuter() end); if ok and valid(o) then tree=o end end
    if not valid(tree) then local ok,o=pcall(function() return w:GetOuter() end); if ok and valid(o) then tree=o end end
    if valid(overlay) and fullname(overlay):find("Overlay",1,true) and valid(tree) then
      local box=make_widget("/Script/UMG.SizeBox",tree)
      local root=make_widget("/Script/UMG.Overlay",tree)
      local capBox=make_widget("/Script/UMG.SizeBox",tree)
      local capOuter=make_widget("/Script/UMG.Border",tree)
      local capInner=make_widget("/Script/UMG.Border",tree)
      local text=make_widget("/Script/UMG.TextBlock",tree)
      local lineBox=make_widget("/Script/UMG.SizeBox",tree)
      local line=make_widget("/Script/UMG.Border",tree)
      if valid(box) and valid(root) and valid(capBox) and valid(capOuter) and valid(capInner)
          and valid(text) and valid(lineBox) and valid(line) then
        pcall(function() box:SetWidthOverride(46.0); box:SetHeightOverride(54.0); box:SetContent(root) end)

        -- One outer outline only; no nested key-icon artwork or internal outline.
        pcall(function()
          capBox:SetWidthOverride(34.0); capBox:SetHeightOverride(34.0); capBox:SetContent(capOuter)
          capOuter:SetBrushColor({R=0.10,G=0.10,B=0.09,A=1.0})
          capOuter:SetPadding({Left=1,Top=1,Right=1,Bottom=1})
          capOuter:SetContent(capInner)
          capInner:SetBrushColor({R=0.64,G=0.62,B=0.56,A=1.0})
          capInner:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
          capInner:SetContent(text)
          text:SetJustification(1)
          text:SetColorAndOpacity({SpecifiedColor={R=0.03,G=0.03,B=0.03,A=1.0},ColorUseRule=0})
          text.Font.Size=22
        end)
        local cs=root:AddChildToOverlay(capBox)
        if valid(cs) then cs:SetHorizontalAlignment(2); cs:SetVerticalAlignment(2); cs:SetPadding({Left=0,Top=0,Right=0,Bottom=8}) end

        pcall(function()
          lineBox:SetWidthOverride(28.0); lineBox:SetHeightOverride(4.0); lineBox:SetContent(line)
          line:SetBrushColor({R=0.0,G=0.0,B=0.0,A=1.0})
        end)
        local sl=root:AddChildToOverlay(lineBox)
        if valid(sl) then sl:SetHorizontalAlignment(2); sl:SetVerticalAlignment(3); sl:SetPadding({Left=0,Top=0,Right=0,Bottom=2}) end

        local oks,slot=pcall(function() return overlay:AddChildToOverlay(box) end)
        if oks and valid(slot) then
          local oldslot=safe(w,"Slot")
          if valid(oldslot) then
            local pad=safe(oldslot,"Padding"); if pad then pcall(function() slot:SetPadding(pad) end) end
            local ha=safe(oldslot,"HorizontalAlignment"); if ha~=nil then pcall(function() slot:SetHorizontalAlignment(ha) end) end
            local va=safe(oldslot,"VerticalAlignment"); if va~=nil then pcall(function() slot:SetVerticalAlignment(va) end) end
          end
          rec={box=box,text=text,line=lineBox}; KeyVisuals[id]=rec
        end
      end
    end
  end
  if not rec then return false end
  if rec.vk~=vk then
    if pcall(function() rec.text:SetText(FText(key_label(vk))) end) then rec.vk=vk end
  end
  if rec.hold~=hold then
    if pcall(function() rec.line:SetRenderOpacity(hold==1 and 1.0 or 0.0) end) then rec.hold=hold end
  end
  pcall(function() rec.box:SetRenderOpacity(1.0) end)
  -- Keep the RebelInputWidget only as the layout anchor; its native key artwork is hidden.
  pcall(function() w:SetRenderOpacity(0.0) end)
  return true
end
local function set_key_widget(w,vk,hold,sys)
  if not valid(w) or not VK_TO_FKEY[vk] then return false end
  return ensure_key_visual(w,vk,hold)
end
local function bindings_widget(owner,props)
  for _,p in ipairs(props) do local w=safe(owner,p); if valid(w) then return w end end
end
local function override_icons(ability,consumable,verbose)
  local ab=bindings_widget(ability,{"WBP_AA_Quickslots_Bindings","Bindings","QuickslotBindingsRadial"})
  local cb=bindings_widget(consumable,{"WBP_HUD_Quickslots_Bindings","Bindings","QuickslotBindingsRadial"})
  local n=0
  for slot=1,4 do
    local direction=SLOT_WIDGET[slot]
    if valid(ab) and set_key_widget(safe(ab,direction),Config["Ability"..slot],Config["Ability"..slot.."Mode"],nil) then n=n+1 end
    if valid(cb) and set_key_widget(safe(cb,direction),Config["Consumable"..slot],Config["Consumable"..slot.."Mode"],nil) then n=n+1 end
  end
  if verbose then log("HUD key widgets updated: "..n.."/8.") end
  return n
end
local function override_skill_wheel(verbose)
  local n=0
  local ok,radials=pcall(function() return FindAllOf("WBP_Combat_Focus_QuickslotBindingsRadial_C") end)
  if ok and radials then for _,radial in ipairs(radials) do
    if valid(radial) and not fullname(radial):find("Default__",1,true) then
      for slot=1,4 do
        local entity=safe(radial,SLOT_WIDGET[slot])
        local nested=valid(entity) and safe(entity,"Button") or nil
        local button=valid(nested) and nested or entity
        if set_key_widget(button,Config["Ability"..slot],Config["Ability"..slot.."Mode"],nil) then n=n+1 end
      end
    end
  end
  end
  if verbose and n>0 then log("Skill-wheel key widgets updated: "..n.." widget(s) across all live radial wheels.") end
  return n
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
  local ok,prompts=pcall(function() return FindAllOf("WBP_HUD_Quickslots_ChangePrompt_C") end)
  if ok and prompts then for _,prompt in ipairs(prompts) do
    if valid(prompt) and not fullname(prompt):find("Default__",1,true) then hide(prompt) end
  end end
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
-- before Lua is entered. The persistent visual guard below already reapplies
-- the same badges after native widget updates without hooking that function.
refresh_hud_visuals=function(verbose,hud)
  -- Re-read the persisted visual choice whenever the HUD is rebuilt/reset.
  -- This keeps death/load reconstruction consistent with the Mod Menu checkbox.
  local h=hud or game_hud(); if not valid(h) then if verbose then log("GUI: no live GameHUD.") end; return false end
  for id,rec in pairs(KeyVisuals) do
    if not valid(rec.box) or not valid(rec.text) or not valid(rec.line) then KeyVisuals[id]=nil end
  end
  local s=safe(h,"QuickslotsSwitcher"); local a=safe(h,"WBP_AA_Quickslots"); local c=safe(h,"WBP_HUD_Quickslots")
  if not valid(s) or not valid(a) or not valid(c) then if verbose then log("GUI: quickslot widgets not ready.") end; return false end
  if not belongs(h,s) or not belongs(h,a) or not belongs(h,c) then if verbose then log("GUI: stale HUD tree rejected.") end; return false end
  local ax,ay,cx,cy=wheel_offsets()
  local laidOut,layoutError=WheelLayout:Update(h,s,a,c,Config.ShowBothWheels~=0,ax,ay,cx,cy)
  if not laidOut then
    if LastLayoutError~=layoutError then log("GUI layout pending: "..tostring(layoutError)); LastLayoutError=layoutError end
  else LastLayoutError=nil end
  override_icons(a,c,verbose)
  override_skill_wheel(verbose)
  if laidOut and Config.ShowBothWheels~=0 then hide_swap_prompt(h,a) end
  return laidOut
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
local function queue_radial_refresh()
  if not VisualGuardArmed or RadialRefreshPending then return end
  RadialRefreshPending=true
  ExecuteWithDelay(1,function()
    ExecuteInGameThread(function()
      RadialRefreshPending=false
      if Config.Enabled~=0 and VisualGuardArmed then override_skill_wheel(false) end
    end)
  end)
end

-- Hide newly-created native swap prompts immediately. This prevents the native prompt
-- flashing before the periodic fallback guard gets its first pass.
if Config.Enabled~=0 then pcall(function()
  NotifyOnNewObject("/Game/_Dawnwalker/UI/_Unified/HUD/Quickslots/WBP_HUD_Quickslots_ChangePrompt.WBP_HUD_Quickslots_ChangePrompt_C",function(o)
    if Config.ShowBothWheels~=0 and valid(o) then WheelLayout:HidePrompt(o) end
  end)
end) end

if Config.Enabled~=0 then pcall(function()
  RegisterHook("/Game/_Dawnwalker/UI/_Unified/HUD/CombatFocus/WBP_Combat_Focus_QuickslotBindingsRadial.WBP_Combat_Focus_QuickslotBindingsRadial_C:Rebuild All",function() end,function()
    queue_radial_refresh()
  end)
end) end

if Config.Enabled~=0 then pcall(function()
  NotifyOnNewObject("/Game/_Dawnwalker/UI/_Unified/HUD/CombatFocus/WBP_Combat_Focus_QuickslotBindingsRadial.WBP_Combat_Focus_QuickslotBindingsRadial_C",function()
    queue_radial_refresh()
  end)
end) end

-- One completion-paced loop owns discovery and native-display recovery. Keep the
-- 500 ms recovery fallback until all native reset events have verified safe hooks.
local AutoHudApplied=false
local AutoHudName=""
local function auto_hud_apply_loop()
  ExecuteWithDelay(AutoHudApplied and 500 or 250,function()
    ExecuteInGameThread(function()
     if Config.Enabled~=0 then
      local h=game_hud(); local n=valid(h) and fullname(h) or ""
      if n~="" and n~=AutoHudName then
        AutoHudApplied=false
        if apply_hud(h) then AutoHudName=n; AutoHudApplied=true end
      elseif n~="" then
        AutoHudApplied=refresh_hud_visuals(false,h)
        if not AutoHudApplied then AutoHudName="" end
      elseif n=="" then
        AutoHudApplied=false; AutoHudName=""
      end
     end
     if Config.Enabled~=0 then auto_hud_apply_loop() end
    end)
  end)
end
if Config.Enabled~=0 then auto_hud_apply_loop() end

-- Mod Menu Apply writes config.ini. Reconfigure bindings and persistent HUD widgets
-- in place so existing custom keycaps are updated rather than duplicated by a Lua
-- restart. Master/cleanup-toggle changes still restart because they determine which
-- hooks and watchdogs are installed at module load. Preset edits remain in memory
-- until Apply.
local Armed=false
local function reconfigure_from_text(now)
  local previous=Config
  local updated=load_config(now)
  if updated.Enabled~=previous.Enabled
      or updated.RemoveDefinedActionBindings~=previous.RemoveDefinedActionBindings then
    local restored,restoreError=WheelLayout:RestoreAll()
    if not restored then log("GUI restoration pending before restart: "..tostring(restoreError)); return true end
    local sub=valid(Enhanced.sub) and Enhanced.sub or live_subsystem()
    if not clear_bridge_bindings() then return true end
    Enhanced.ready=false
    if not clear_old_context(sub) then return true end
    LastConfigText=now
    RestartCurrentMod()
    return false
  end

  Config=updated
  LastConfigText=now
  local inputChanged=updated.HoldThresholdMs~=previous.HoldThresholdMs
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
  refresh_hud_visuals(false)
  log("Applied committed config changes; input rebuild="..tostring(inputChanged)..".")
  return true
end
local function watch()
  ExecuteWithDelay(750,function()
    local now=readall(CONFIG_PATH)
    if now==nil or not now:match("%[General%]") or not now:match("%[Bindings%]") then watch(); return end
    if Armed and now~=LastConfigText then
      ExecuteInGameThread(function()
        if reconfigure_from_text(now) then watch() end
      end)
      return
    end
    LastConfigText=now; Armed=true; watch()
  end)
end
watch()
log("Loaded v"..VERSION..(Config.Enabled~=0 and ". Auto-initialization is deferred until the local player/HUD are live." or ". Disabled in Mod Menu; gameplay/HUD initialization skipped."))
