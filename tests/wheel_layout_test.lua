local factory=assert(loadfile("Scripts/wheel_layout.lua"))()
assert(loadfile("Scripts/main.lua"))
local function fixture(abilityFirst)
  local mutations=0
  local function slot()
    return {valid=true,Padding={Left=1,Top=2,Right=3,Bottom=4},HorizontalAlignment=2,VerticalAlignment=3,
      SetPadding=function(self,v) self.Padding=v end,
      SetHorizontalAlignment=function(self,v) self.HorizontalAlignment=v end,
      SetVerticalAlignment=function(self,v) self.VerticalAlignment=v end}
  end
  local function widget(id)
    return {id=id,valid=true,Slot=slot(),RenderTransform={Translation={X=7,Y=9}},opacity=0.8,
      SetRenderTranslation=function(self,v) mutations=mutations+1; self.RenderTransform.Translation=v end,
      GetRenderOpacity=function(self) return self.opacity end,
      SetRenderOpacity=function(self,v) mutations=mutations+1; self.opacity=v end}
  end
  local function panel(id)
    local p=widget(id); p.children={}; p.active=0
    function p:GetChildrenCount() return #self.children end
    function p:GetChildAt(i) return self.children[i+1] end
    function p:RemoveChild(w)
      for i,v in ipairs(self.children) do if v==w then
        mutations=mutations+1; table.remove(self.children,i); w.parent=nil; w.Slot=nil
        self.active=math.min(self.active,math.max(0,#self.children-1)); return true
      end end
      return false
    end
    function p:AddChild(w)
      mutations=mutations+1
      if w.parent then w.parent:RemoveChild(w) end
      self.children[#self.children+1]=w; w.parent=self; w.Slot=slot(); return w.Slot
    end
    function p:GetActiveWidgetIndex() return self.active end
    function p:SetActiveWidgetIndex(i) mutations=mutations+1; self.active=i end
    function p:SetActiveWidget(w) for i,c in ipairs(self.children) do if c==w then self:SetActiveWidgetIndex(i-1); return end end end
    return p
  end
  local f={hud=widget("hud"),owner=panel("owner"),s=panel("switcher"),a=widget("ability"),c=widget("consumable"),prompt=widget("prompt")}
  f.owner:AddChild(f.s)
  f.s:AddChild(abilityFirst and f.a or f.c); f.s:AddChild(abilityFirst and f.c or f.a)
  f.s.active=1; f.a.Slot.Padding.Top=23
  mutations=0
  local env={valid=function(w) return w and w.valid end,safe=function(o,k) return o and o[k] end,
    unwrap=function(v) return v end,parent=function(w) return w.parent end,
    same=function(a,b) return a~=nil and a==b and a.valid end,fullname=function(w) return w.id end}
  f.layout=factory(env)
  function f:update(on) return self.layout:Update(self.hud,self.s,self.a,self.c,on,20,40,40,-420) end
  function f:count() return mutations end
  f.widget=widget
  return f
end
for _,abilityFirst in ipairs({false,true}) do
  local f=fixture(abilityFirst)
  assert(f:update(false)); assert(f:count()==0,"off initially leaves native layout untouched")
  assert(f:update(true)); assert(f.a.parent==f.owner and f.c.parent==f.s and #f.s.children==1)
  assert(f.layout:HidePrompt(f.prompt)); assert(f.prompt.opacity==0)
  assert(f:update(true)); assert(f.layout:HidePrompt(f.prompt)) -- Do not overwrite originals.
  assert(f.a.RenderTransform.Translation.X==20 and f.s.RenderTransform.Translation.Y==-420)
  assert(f:update(false)); assert(f.a.parent==f.s and f.c.parent==f.s and #f.s.children==2)
  assert(f.s.children[1]==(abilityFirst and f.a or f.c) and f.s.active==1,"native order and selection restored")
  assert(f.a.Slot.Padding.Top==23 and f.a.Slot.HorizontalAlignment==2,"switcher slot restored")
  assert(f.a.RenderTransform.Translation.X==7 and f.s.RenderTransform.Translation.Y==9 and f.prompt.opacity==0.8)
  f.s.active=0; local before=f:count(); assert(f:update(false)); assert(f:count()==before and f.s.active==0,"native swap remains in control")
  assert(f:update(true)); assert(f.layout:RestoreAll()); assert(f.s.active==0,"second enable captures latest native selection")
end
do
  local f=fixture(); f.owner.AddChild=function() error("attachment failed") end
  assert(not f:update(true)); assert(f.a.parent==f.s and f.c.parent==f.s and #f.s.children==2,"failed detach/attach restores native layout")
end
do
  local f=fixture(); f.a.RenderTransform=nil
  assert(not f:update(true)); assert(f:count()==0,"unreadable baseline must fail before mutation")
end
do
  local f=fixture(); assert(f:update(true))
  local stranger=f.widget("external"); f.s:AddChild(stranger)
  assert(not f:update(false)); assert(stranger.parent==f.s,"never remove external switcher children")
  f.s:RemoveChild(stranger); assert(f:update(false),"restoration remains retryable")
end
do
  local f=fixture(); assert(f:update(true)); f.hud.valid=false
  assert(f.layout:RestoreAll(),"invalid old HUD can be discarded")
end
print("PASS: native/dual layout transitions, restoration and failure safety")
