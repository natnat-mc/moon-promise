import async, await, Promise from require 'moon-promise'
copas=require 'copas'

increment=(val) ->
	return Promise (res, rej) ->
		copas.sleep 1
		res val+1

fn=async (i) ->
	print i -- 1
	i=await increment i
	print i -- 2
	i=await increment i
	print i -- 3
	return increment i

(fn 1)\andthen (i) ->
	print i-- 4

copas.loop()
