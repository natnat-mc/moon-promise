copas=require 'copas'

local Promise, async, await

events={}

--BEGIN Promise implementation
class Promise
	-- call a function asynchronously in its own copas thread
	@_invoke=(fn) ->
		copas.addthread () ->
			copas.sleep 0
			fn!
	
	-- return a Promise that resolves with val
	@resolve=(val) ->
		Promise (res, rej) ->
			res val
	
	-- returns a Promise that rejects with reason
	@reject=(reason) ->
		Promise (res, rej) ->
			rej reason
	
	-- return a Promise that resolves with everything
	@all=(list) ->
		-- build the Promise itself
		pro=Promise (res, rej) ->
			waiting=0
			resolved={}
			values={}
			for i, pro in ipairs list
				if ('table'==type pro) and Promise==pro.__class
					waiting+=1
					resfn=(val) ->
						unless resolved[i]
							resolved[i]=true
							waiting-=1
							values[i]=val
							if waiting==0
								return res values
					pro\andThen resfn, rej
				else
					values[i]=pro
			if waiting==0
				return res values
		
		-- make it already resolved if the list is empty
		if #list==0
			pro._resolve {}
		
		pro
	
	-- return a Promise that resolves when the first one resolves
	@race=(list) ->
		Promise (res, rej) ->
			for pro in *list
				pro\andThen res, rej
	
	-- returns a Promise that may resolve or reject depending on the behavior of fn
	new: (fn) =>
		-- initialize the default state of the Promise
		@_status='pending'
		@_value, @_reason=nil, nil
		@_resolvehandlers, @_rejecthandlers={}, {}
		
		if fn
			-- call the funtion and attempt to resolve or reject the promise accordingly
			Promise._invoke () ->
				ok, err=pcall fn, @\_resolve, @\_reject
				unless ok
					return @_reject err
	
	-- catch(a) is an alias to andThen(nil, a)
	catch: (fn) => @andThen nil, fn
	
	-- andthen(a, b) is an alias to andThen(a, b)
	andthen: (a, b) => @andThen a, b
	
	-- finally is basically a glorified alias
	finally: (fn) =>
		Promise (res, rej) ->
			resh=(val) ->
				ok, err=pcall fn, val, nil
				if ok
					return res val
				else
					return rej err
			rejh=(reason) ->
				ok, err=pcall  fn, nil, reason
				if ok
					return rej reason
				else
					return rej val
			return @andThen resh, rejh
	
	-- andThen is quite a big deal
	andThen: (resh, rejh) =>
		-- create the returned Promise
		local _res, _rej, _pro
		_pro=Promise (res, rej) ->
			_res, _rej=res, rej
		
		-- handle resolve handler
		resh=((a) -> a) unless 'function'==type resh
		resfn=(val) ->
			ok, val=pcall resh, val
			if ok
				return _pro\_resolve val
			else
				return _pro\_reject val
		if @_status=='resolved'
			Promise._invoke () -> resfn @_value
		elseif @_status=='pending'
			table.insert @_resolvehandlers, resfn
		
		-- handle reject handler
		rejh=((a) -> error a) unless 'function'==type rejh
		rejfn=(reason) ->
			ok, val=pcall rejh, reason
			if ok
				return _pro\_resolve val
			else
				return _pro\_reject val
		if @_status=='rejected'
			Promise._invoke () -> rejfn @_reasson
		elseif @_status=='pending'
			table.insert @_rejecthandlers, rejfn
		
		-- mirror status
		if @_status=='resolved'
			_pro\_resolve @_value
		elseif @_status=='rejected'
			_pro\_reject @_reason
		
		-- return the created Promise
		return _pro
	
	-- _resolve is quite something too, actually
	_resolve: (val) =>
		-- can't resolve with ourselves
		error "A Promise can not be resolved with itself" if @==val
		
		-- resolving is ignored if the Promise isn't pending
		return unless @_status=='pending'
		
		-- attempt to resolve with a Promise
		if ('table'==type val) and val.__class==Promise
			if val._status=='pending' -- mirror state on update
				table.insert val._resolvehandlers, @\_resolve
				return table.insert val._rejecthandlers, @\_reject
			elseif val._status=='resolved' -- mirror resolved state
				return @_resolve val._value
			else -- mirror rejected state
				return @_reject val._value
		
		-- attempt to resolve with a Thenable
		if 'table'==type val
			ok, _then=pcall () -> val.andThen or val.andthen or val['then']
			-- fail if we can't access the then property
			return @_reject _then unless ok
			-- attempt to use the then method
			if 'function'==type _then
				ok, err=pcall () -> _then val, @\_resolve, @\_reject
				return @_reject err unless ok
				return
		
		-- set the state and call handlers
		@_status, @_value='resolved', val
		for handler in *@_resolvehandlers
			Promise._invoke () -> handler val
	
	-- _reject is quite simple
	_reject: (reason) =>
		-- rejecting is ignored if the Promise isn't pending
		return unless @_status=='pending'
		
		-- set the state and call handlers
		@_status, @_reason='rejected', reason
		for handler in *@_rejecthandlers
			Promise._invoke () -> handler reason
--END Promise implementation

--BEGIN async/await implementation
async=(fn) ->
	(...) ->
		p=Promise!
		argc, argv=(select '#', ...), {...}
		unpack=table.unpack or unpack
		copas.addthread () ->
			copas.sleep 0
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
--END async/await implementation

return {
	:Promise
	:async, :await
}
