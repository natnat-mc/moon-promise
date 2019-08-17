local Promise, eloop, copas
do
	ok, Promise=pcall require, 'moon-promise'
	ok, Promise=pcall require, 'lit-promise' unless ok
	ok, Promise=pcall require, 'promise' unless ok
	ok, Promise=pcall require, '.' unless ok
	error "Unable to load main lib" unless ok
	
	ok, eloop=pcall require, 'moon-promise.eloop'
	ok, eloop=pcall require, 'lit-promise.eloop' unless ok
	ok, eloop=pcall require, 'promise.eloop' unless ok
	ok, eloop=pcall require, 'eloop' unless ok
	error "Unable to load eloop" unless ok
	
	ok, copas=pcall require, 'copas'
	error "Unable to load copas" unless ok

async=(fn) ->
	(...) ->
		p=Promise!
		argc, argv=(select '#', ...), {...}
		unpack=table.unpack or unpack
		eloop.addevent () ->
			ok, val=pcall fn, unpack argv, 1, argc
			if ok
				return p\_resolve val
			else
				return p\_reject val
		return p

await=(p) ->
	local ok, val
	
	resfn=(resval) ->
		ok=true
		val=resval
	rejfn=(rejval) ->
		ok=false
		val=rejval
	
	(Promise.resolve p)\andthen resfn, rejfn
	
	while ok==nil
		copas.sleep 0
	if ok
		return val
	else
		error val

return {
	:async, :await
}
