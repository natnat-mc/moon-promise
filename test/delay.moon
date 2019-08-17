Promise=require '.'
eloop=require 'eloop'
copas=require 'copas'

eloop.install()

((((((Promise (ok, ko) ->
	copas.sleep 1
	ok 1
)\andthen (a) ->
	print a -- 1
	copas.sleep 1
	a+1
)\andthen (a) ->
	print a -- 2
	copas.sleep 1
	a+1
)\andthen (a) ->
	print a -- 3
	copas.sleep 1
	error a+1
)\finally (a, b) ->
	print "a: #{a}, b: #{b}" -- a: nil, b: 4
	copas.sleep 1
)\andthen ((a) ->
	print "Oops"
	eloop.stop!
	), (a) ->
	print a -- 4
	copas.sleep 1
	error a+1
)\catch (a) ->
	print a -- 5
	eloop.stop!

copas.loop()
