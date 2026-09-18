-- Context fields only; saved player keys and action objects are never modified.
return function(e)
  local originals={}
  local api={}
  -- Shared scalar journal survives Lua reload; never share UObject wrappers.
  for line in (e.load() or ''):gmatch('[^\n]+') do
    local p,i,a,k,b=line:match('^([^\t]+)\t(%d+)\t([^\t]+)\t([^\t]+)\t(%d+)$')
    if p then originals[p..'\t'..i]={context=p,index=tonumber(i),action=a,key=k,behavior=tonumber(b)} end
  end
  local function save()
    local lines={}
    for _,r in pairs(originals) do lines[#lines+1]=table.concat({r.context,r.index,r.action,r.key,r.behavior},'\t') end
    table.sort(lines);e.save(table.concat(lines,'\n'))
  end
  function api:Apply(contexts)
    for _,c in ipairs(contexts) do
      if e.valid(c) and not e.owned(c) then
        local changed=false
        e.each(c.Mappings,function(i,m)
          if e.target(m.Action) and not (e.key(m)=='None' and m.SettingBehavior==2) then
            local id=e.path(c)..'\t'..i
            if not originals[id] then
              originals[id]={context=e.path(c),index=i,action=e.path(m.Action),key=e.key(m),behavior=m.SettingBehavior}
              save() -- journal before mutation
            end
            m.SettingBehavior=2;m.Key={KeyName=e.name('None')};changed=true
          end
        end)
        if changed then e.rebuild(c) end
      end
    end
    return true
  end
  function api:Restore()
    local changed={}
    local restored={}
    for id,r in pairs(originals) do
      local c=e.resolve(r.context)
      if e.valid(c) then
        local found=false
        e.each(c.Mappings,function(i,m)
          if i==r.index and e.path(m.Action)==r.action then
            found=true
            if e.key(m)=='None' and m.SettingBehavior==2 then
              m.Key={KeyName=e.name(r.key)};m.SettingBehavior=r.behavior
            end
            -- Also rebuild on retry after a previous rebuild request failed.
            changed[r.context]=c
          end
        end)
        if not found then error('Suppression restoration identity changed: '..r.context) end
      end
      restored[#restored+1]=id
    end
    for _,c in pairs(changed) do e.rebuild(c) end
    for _,id in ipairs(restored) do originals[id]=nil end
    save()
    return true
  end
  return api
end
