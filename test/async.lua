local async, await, Promise
do
  local _obj_0 = require('Promise')
  async, await, Promise = _obj_0.async, _obj_0.await, _obj_0.Promise
end
local copas = require('copas')
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
  return print(i)
end)
return copas.loop()
