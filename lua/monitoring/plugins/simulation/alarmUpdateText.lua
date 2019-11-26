#!/usr/bin/lua

local t = os.time()
math.randomseed(t)

function getPseudoRandomString()
   local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
   local length = 12
   local randomString = ''

   local charTable = {}
   for c in chars:gmatch"." do
       table.insert(charTable, c)
   end

   for i = 1, length do
       randomString = randomString..charTable[math.random(1, #charTable)]
   end

   return randomString
end

print("This is PERMANENT alarm which changes TEXT only | "..getPseudoRandomString())
os.exit(1)
