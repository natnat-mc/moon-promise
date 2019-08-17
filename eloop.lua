local _ = [[	This is an event loop used for running promises asynchronously using copas
]]
local events = { }
local running = 'never'
local install
do
  local installed = false
  install = function()
    if installed then
      return 
    end
    installed = true
    local Promise, copas
    do
      local ok
      ok, Promise = pcall(require, 'moon-promise')
      if not (ok) then
        ok, Promise = pcall(require, 'lit-promise')
      end
      if not (ok) then
        ok, Promise = pcall(require, 'promise')
      end
      if not (ok) then
        ok, Promise = pcall(require, '.')
      end
      if not (ok) then
        error("Unable to load main lib")
      end
      ok, copas = pcall(require, 'copas')
      if not (ok) then
        error("Unable to load copas")
      end
    end
    Promise._invoke = function(fn)
      return table.insert(events, fn)
    end
    return copas.addthread(function()
      copas.sleep(0)
      running = 'always'
      while running == 'always' or (running == 'finish' and #events ~= 0) do
        local n = #events
        for i = 1, n do
          local event = table.remove(events, 1)
          copas.addthread(event)
        end
        for i = 1, math.min(n, #events) do
          local event = table.remove(events, 1)
          copas.addthread(event)
        end
        copas.sleep(0)
      end
    end)
  end
end
local addevent
addevent = function(fn, ...)
  local n = select('#', ...)
  if n ~= 0 then
    local args = {
      ...
    }
    local realfn = fn
    fn = function()
      return realfn(table.unpack(args, 1, n))
    end
  end
  return table.insert(events, fn)
end
local stop
stop = function(force)
  if force == nil then
    force = false
  end
  running = force and 'never' or 'finish'
end
return {
  events = events,
  addevent = addevent,
  install = install,
  stop = stop
}
