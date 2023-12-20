-- example script that adds a query string

local threadcounter = 1
local threads = {}

function setup(thread)
 thread:set("id", threadcounter)
 table.insert(threads, thread)
 threadcounter = threadcounter + 1
end

function init(args)
 math.randomseed(0xdeadfeed * id)
end

function delay()
 return 0
end

function fdelay()
 local r = math.random(0, 50)

 return r
end

request = function()
 local param_value = math.random(12000)
 hostname = ""
 path = "/_10kobjectVIDEO?version=" .. hostname .. param_value

 return wrk.format("GET", path)
end