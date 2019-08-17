[[
	Considerations:
		- "Promise(fn)" called with a function "fn(a, b)" will create a promise that will be resolved with "value" when "a(value)" is called or rejected if "fn" throws or "b(reason)" is called
		- "Promise.resolve(val)" returns a promise that is resolved with either "val" or the resolved value of "val"
		- "Promise.reject(reason)" returns a promise that is rejected with "reason"
		- "Promise.all(list)" returns a promise that is resolved when all the promises in the list are resolved, or rejected when one of them is rejected
		- "Promise.race(list)" returns a promise that mirrors the state of the first settled promise in the list
		
		- "Promise._invoke(fn)" is a function that attempts to call "fn" without arguments asynchronously with an empty execution stack
		- "Promise._invoke" can safely be overwritten with any function that does this, and in fact should be, since its default implementation isnt conformant
		
		- "promise.then(a, b)" is invalid in lua and in moonscript, so it becomes "promise.andThen(a, b)" and "promise.andthen(a, b)" is a valid alias
		- "promise.catch(a)" is an alias to "promise.andThen(nil, a)"
		- "promise.finally(a)" behaves as "promise.andThen(b, b)" where "b" is a function that calls "a(val, err)" and returns a promise that is either rejected if "a" throws or assumes the state of "promise"
		
		- "promise._status" is either "pending", "resolved" or "rejected"
		- "promise._value" is the value of the promise, if it is resolved
		- "promise._reason" is the reason of the rejection of the promise, if it is rejected
		- "promise._resolve(val)" resolves "promise" with either "val" or the resolved value of "val"
		- "promise._reject(reason)" rejects "promise" with "reason"
		- "promise._resolvehandlers" is a table containing all the functions to be called when "promise" is resolved
		- "promise._rejecthandlers" is a table containing all the functions to be called when "promise" is rejected
		- the "_status", "promise._reason", "_resolve", "_reject", "_resolvehandlers" and "_rejecthandlers" properties are to be considered private and as such should not be used by external code
		
]]

class Promise
	-- call a function "asynchronously", "on an empty stack"
	@_invoke=(fn) ->
		if process and process.nextTick
			process.nextTick fn
		elseif setTimeout
			setTimeout fn, 0
		else
			-- this is probably not compliant, but hey, it's all we got
			pcall fn
	
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
