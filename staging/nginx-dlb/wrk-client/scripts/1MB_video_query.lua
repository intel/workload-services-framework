-- example script that adds a query string

local threadcounter = 1
local threads = {}

function setup(thread)
 thread:set("id", threadcounter)
 table.insert(threads, thread)
 threadcounter = threadcounter + 1
end

function init(args)
 -- math.randomseed(os.time()*id)
 math.randomseed(0xdeadfeed * id)
end

function delay()
 -- return 1000
 return 0
end

function fdelay()
 local r = math.random(0, 50)
 -- print ("fdelay = " .. r)
 return r
end

request = function()
-- local param_value = math.random(800000)
 local param_value = math.random(12000)
-- hostname =string.gsub(hostname, "\n$", "")
 hostname = ""
 path = "/_1mobjectVIDEO?version=" .. hostname .. param_value .. "&thread=" .. id

 -- print ("time: " .. os.time() .. " -- thread" .. id .. ":" .. path)
 return wrk.format("GET", path)
end
