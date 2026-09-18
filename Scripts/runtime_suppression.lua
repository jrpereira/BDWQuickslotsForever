-- Context fields only; saved player keys and action objects are never modified.
return function(e)
  local originals={}
  local pendingRebuild={}
  local checked={}
  local api={}
  -- Shared scalar journal survives Lua reload; old five-field records still load.
  for line in (e.load() or ''):gmatch('[^\n]+') do
    local p,i,a,k,b,tail=line:match('^([^\t]+)\t(%d+)\t([^\t]+)\t([^\t]+)\t(%d+)(.*)$')
    if p then
      local signature,writing=tail:match('^\t([^\t]*)\t([01])$')
      originals[p..'\t'..i]={context=p,index=tonumber(i),action=a,key=k,behavior=tonumber(b),
        signature=signature or (tail:sub(1,1)=='\t' and tail:sub(2) or nil),writing=writing=='1'}
    end
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
      if r.signature~=nil then line=line..'\t'..r.signature..'\t'..(r.writing and '1' or '0') end
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
    -- Blanked equivalent rows cannot identify a survivor after deletion or a
    -- mixed external edit. Preserve evidence and fail before any writes instead
    -- of silently restoring an arbitrary original key. Native Controls changes
    -- normally avoid this state by restoring before the game's remap operation.
    for _,r in ipairs(prior) do
      local oldCount,newCount,blank,external=0,0,0,false
      for _,other in ipairs(prior) do
        if other.action==r.action and other.signature==r.signature then oldCount=oldCount+1 end
      end
      if oldCount>1 then
        for _,row in ipairs(rows) do if matches(r,row) then
          newCount=newCount+1
          if suppressed(row.mapping) then blank=blank+1
          else
            local known=false
            for _,old in ipairs(prior) do
              if matches(old,row) and old.key==e.key(row.mapping) then known=true;break end
            end
            if not known then external=true end
          end
        end end
        assert(blank==0 or (newCount==oldCount and not external),
          'Ambiguous suppressed mappings; native Controls reset required: '..path..' '..r.action)
      end
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
            behavior=r.behavior,signature=row.signature,writing=r.writing}
        end
      elseif capture then
        -- The game supplied a new binding: this is now the value to restore.
        row.original={context=path,index=row.index,action=row.action,key=e.key(row.mapping),
          behavior=row.mapping.SettingBehavior,signature=row.signature}
        -- A failed property write is our unfinished transaction, not a new
        -- native Controls choice. Keep its pre-write behavior across retries.
        for _,r in ipairs(prior) do
          if r.writing and matches(r,row) and r.index==row.index and r.key==e.key(row.mapping) then
            row.original.behavior=r.behavior;row.original.writing=true;break
          end
        end
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
          if row.original then
            if not suppressed(row.mapping) then row.original.writing=true end
            originals[path..'\t'..row.index]=row.original
          end
        end
        save() -- journal the reconciled native values before any mutation
        for _,row in ipairs(rows) do
          local m=row.mapping
          if not suppressed(m) then
            pendingRebuild[path]=c
            m.SettingBehavior=2;m.Key={KeyName=e.name('None')}
          end
        end
        for _,row in ipairs(rows) do if row.original then row.original.writing=false end end
        save()
        checked[path]=c
      end
    end
    return self:RetryRebuilds()
  end
  function api:Restore()
    checked={}
    local contexts={}
    for _,r in pairs(originals) do contexts[r.context]=true end
    local plans={}
    for path in pairs(contexts) do
      local c=e.resolve(path)
      if e.valid(c) then plans[#plans+1]={context=c,path=path,rows=reconcile(c,false)} end
    end
    -- Validate every context before restoring any; journal partial restoration
    -- too, so an interrupted disable cannot become a false native baseline.
    for _,r in pairs(originals) do r.writing=true end
    if next(originals) then save() end
    for _,plan in ipairs(plans) do
      pendingRebuild[plan.path]=plan.context
      for _,row in ipairs(plan.rows) do
        if row.original then
          local r=row.original
          row.mapping.Key={KeyName=e.name(r.key)};row.mapping.SettingBehavior=r.behavior
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
