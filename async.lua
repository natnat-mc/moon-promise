local Promise, eloop, copas
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
  ok, eloop = pcall(require, 'moon-promise.eloop')
  if not (ok) then
    ok, eloop = pcall(require, 'lit-promise.eloop')
  end
  if not (ok) then
    ok, eloop = pcall(require, 'promise.eloop')
  end
  if not (ok) then
    ok, eloop = pcall(require, 'eloop')
  end
  if not (ok) then
    error("Unable to load eloop")
  end
  ok, copas = pcall(require, 'copas')
  if not (ok) then
    error("Unable to load copas")
  end
end
local async
async = function(fn)
  return function(...)
    local p = Promise()
    local argc, argv = (select('#', ...)), {
      ...
    }
    local unpack = table.unpack or unpack
    eloop.addevent(function()
      local ok, val = pcall(fn, unpack(argv, 1, argc))
      if ok then
        return p:_resolve(val)
      else
        return p:_reject(val)
      end
    end)
    return p
  end
end
local await
await = function(p)
  local ok, val
  local resfn
  resfn = function(resval)
    ok = true
    val = resval
  end
  local rejfn
  rejfn = function(rejval)
    ok = false
    val = rejval
  end
  (Promise.resolve(p)):andthen(resfn, rejfn)
  while ok == nil do
    copas.sleep(0)
  end
  if ok then
    return val
  else
    return error(val)
  end
end
return {
  async = async,
  await = await
}
