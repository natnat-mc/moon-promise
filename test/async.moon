Promise=require '.'
copas=require 'copas'
import async, await from require 'async'

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
	os.exit 0

(require 'eloop').install!
copas.loop()
