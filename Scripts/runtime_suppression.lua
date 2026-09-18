-- Context fields only; saved player keys and action objects are never modified.
return function(e)
  local originals={}
  local pendingRebuild={}
  local checked={}
  local api={}
  -- Shared scalar journal survives Lua reload; old five-field records still load.
  for line in (e.load() or ''):gmatch('[^\n]+') do
    local p,i,a,k,b,tail=line:match('^([^\t]+)\t(%d+)\t([^\t]+)\t([^\t]+)\t(%d+)(.*)$')
    if p then originals[p..'\t'..i]={context=p,index=tonumber(i),action=a,key=k,behavior=tonumber(b),
      signature=tail:sub(1,1)=='\t' and tail:sub(2) or nil} end
  end
  if e.resolve then
    for _,r in pairs(originals) do
      local c=e.resolve(r.context)
      if e.valid(c) then pendingRebuild[r.context]=c end
    end
  end
  function api:Invalidate(context)
    if context then checked[e.path(context)]=nil else checked={} end
  end
  function api:RetryRebuilds()
    for path,context in pairs(pendingRebuild) do
      if e.valid(context) then assert(e.rebuild(context)~=false,'Suppression rebuild rejected') end
      pendingRebuild[path]=nil
    end
    return true
  end
  local function save()
    local lines={}
    for _,r in pairs(originals) do
      local line=table.concat({r.context,r.index,r.action,r.key,r.behavior},'\t')
      if r.signature~=nil then line=line..'\t'..r.signature end
      lines[#lines+1]=line
    end
    table.sort(lines);e.save(table.concat(lines,'\n'))
  end
  local function suppressed(m) return e.key(m)=='None' and m.SettingBehavior==2 end
  -- Match surviving rows first. An index is a hint, never the identity itself.
  -- Rows with identical action/trigger/modifier/settings signatures are equivalent;
  -- preserve one original per row, including multiple keys for the same action.
  local function reconcile(c,capture)
    local path=e.path(c)
    local prior,rows={},{}
    for _,r in pairs(originals) do if r.context==path then prior[#prior+1]=r end end
    table.sort(prior,function(a,b) return a.index<b.index end)
    e.each(c.Mappings,function(i,m)
      if e.target(m.Action) then
        rows[#rows+1]={index=i,mapping=m,action=e.path(m.Action),
          signature=e.signature and e.signature(m) or ''}
      end
    end)
    table.sort(rows,function(a,b) return a.index<b.index end)
    local used={}
    local function matches(r,row)
      return r.action==row.action and (r.signature==nil or r.signature==row.signature)
    end
    for _,row in ipairs(rows) do
      if suppressed(row.mapping) then
        local chosen
        for j,r in ipairs(prior) do
          if not used[j] and matches(r,row) then
            chosen=chosen or j
            if r.index==row.index then chosen=j;break end
          end
        end
        if chosen then
          used[chosen]=true
          local r=prior[chosen]
          row.original={context=path,index=row.index,action=row.action,key=r.key,
            behavior=r.behavior,signature=row.signature}
        end
      elseif capture then
        -- The game supplied a new binding: this is now the value to restore.
        row.original={context=path,index=row.index,action=row.action,key=e.key(row.mapping),
          behavior=row.mapping.SettingBehavior,signature=row.signature}
      end
    end
    return rows
  end
  function api:Apply(contexts)
    for _,c in ipairs(contexts) do
      local path=e.valid(c) and e.path(c)
      if path and not e.owned(c) and not e.valid(checked[path]) then
        local rows=reconcile(c,true)
        for id,r in pairs(originals) do if r.context==path then originals[id]=nil end end
        for _,row in ipairs(rows) do
          if row.original then originals[path..'\t'..row.index]=row.original end
        end
        save() -- journal the reconciled native values before any mutation
        for _,row in ipairs(rows) do
          local m=row.mapping
          if not suppressed(m) then
            pendingRebuild[path]=c
            m.SettingBehavior=2;m.Key={KeyName=e.name('None')}
          end
        end
        checked[path]=c
      end
    end
    return self:RetryRebuilds()
  end
  function api:Restore()
    checked={}
    local contexts={}
    for _,r in pairs(originals) do contexts[r.context]=true end
    for path in pairs(contexts) do
      local c=e.resolve(path)
      if e.valid(c) then
        -- Keep the rebuild obligation even if a previous Restore changed fields
        -- successfully but its rebuild failed. External updates are left alone.
        pendingRebuild[path]=c
        for _,row in ipairs(reconcile(c,false)) do
          if row.original then
            local r=row.original
            row.mapping.Key={KeyName=e.name(r.key)};row.mapping.SettingBehavior=r.behavior
          end
        end
      end
    end
    self:RetryRebuilds()
    originals={}
    save()
    return true
  end
  return api
end
