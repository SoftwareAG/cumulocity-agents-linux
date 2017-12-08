local tbl = {}

function init()
   c8y:addMsgHandler(805, 'aggregate')
   c8y:addMsgHandler(806, 'perform')
   return 0
end


function aggregate(r)
   table.insert(tbl, {r:value(2), r:value(3), r:value(4)})
end


function perform(r)
   for k, v in pairs(tbl) do
      local id = string.match(v[3], '/(%w+)$')
      if id then print(id, v[1] .. '_' .. v[2] .. '.ipk') end
   end
   tbl = {}
   c8y:send('304,' .. r:value(2) .. ',"Not supported yet."')
end
