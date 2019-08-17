[[
	This is an event loop used for running promises asynchronously using copas
]]

-- the event queue itself
events={}
-- the running state
running='never'

-- installation function
install=do
	installed=false
	() ->
		-- don't install if already installed
		return if installed
		installed=true
		
		-- load the Promise and copas libs
		local Promise, copas
		do
			ok, Promise=pcall require, 'moon-promise'
			ok, Promise=pcall require, 'lit-promise' unless ok
			ok, Promise=pcall require, 'promise' unless ok
			ok, Promise=pcall require, '.' unless ok
			error "Unable to load main lib" unless ok
			
			ok, copas=pcall require, 'copas'
			error "Unable to load copas" unless ok
		
		-- Promise._invoke now adds a function to the event queue
		Promise._invoke=(fn) ->
			table.insert events, fn
		
		-- add a new thread to copas
		copas.addthread () ->
			-- wait until we have run a loop
			copas.sleep 0
			running='always'
			
			-- loop forever and wait for events
			while running=='always' or (running=='finish' and #events!=0)
				-- run all the active events
				n=#events
				for i=1, n
					event=table.remove events, 1
					copas.addthread event
				
				-- run at most the same number of events that have been created during the first loop*
				-- this avoids infinite loops but avoids unnecessary calls to copas
				for i=1, math.min n, #events
					event=table.remove events, 1
					copas.addthread event
				
				-- let copas do stuff
				copas.sleep 0

-- add a function to the event queue
addevent=(fn, ...) ->
	-- if multiple arguments are given, wrap them in a function
	n=select '#', ...
	if n!=0
		args={...}
		realfn=fn
		fn=() -> realfn table.unpack args, 1, n
	
	-- add the function the event queue
	table.insert events, fn

-- stop function
stop=(force=false) ->
	running=force and 'never' or 'finish'

-- return the exported properties
{
	:events
	:addevent
	:install
	:stop
}
