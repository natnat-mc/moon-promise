local Promise = require('.')
local copas = require('copas')
local async, await
do
  local _obj_0 = require('async')
  async, await = _obj_0.async, _obj_0.await
end
local increment
increment = function(val)
  return Promise(function(res, rej)
    copas.sleep(1)
    return res(val + 1)
  end)
end
local fn = async(function(i)
  print(i)
  i = await(increment(i))
  print(i)
  i = await(increment(i))
  print(i)
  return increment(i)
end);
(fn(1)):andthen(function(i)
  print(i)
  return os.exit(0)
end);
(require('eloop')).install()
return copas.loop()
