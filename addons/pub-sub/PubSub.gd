"""
Publish-Subscribe mechanism

Only one subscription per object per event is allowed.
Invalid or queued-for-deletion objects will not trigger event handlers.

subscribe/unsubscribe parameters: listener, event_key
publish parameters: event_key, payload
"""
extends Node
class_name PubSub


static var subscriptions = {}
static var instant_subscriptions = {}
static var published_async = []
static var all_events = []
static var services = {}

const event_handler_name = "event_published"
const instant_event_hanlder_name = "instant_event_published"


static func is_valid(listener)->bool:
	"""
	Confirm the listener instance is valid and is not queued for deletion.
	"""
	if !is_instance_valid(listener):
		return false
	if listener is Node:
		return !listener.is_queued_for_deletion()
	else:
		return true


static func is_a_listener(obj, method_name)->bool:
	"""
	Confirm the listener is valid and has event handler.
	"""
	return is_valid(obj) and obj.has_method(method_name)


static func subscribe(listener, event_key = null)->void:
	"""
	Subscribes listener to the given event_key, or all event_keys if not supplied.
	"""
	if !is_a_listener(listener, event_handler_name):
		# Invalid object or No method to call
		return

	if event_key==null:
		# Subscribe to all events
		all_events.append(listener)
	else:
		# add a listener to the listener list.
		var listeners = subscriptions.get_or_add(event_key, [])
		# Ensure subscription once.
		if !listeners.has(listener):
			listeners.append(listener)


static func unsubscribe(listener, event_key = null)->void:
	"""
	Unsubscribes listener from event_key, or all event_keys if not supplied
	"""
	#var erase_all = func(arr):
	#	arr.filter(func(v): return v != listener)
	# MEMO: Use this lambda function to handle multiple subscriptions per object.

	if event_key==null:
		# remove all subscriptions
		for listeners in subscriptions.values():
			listeners.erase(listener)
		all_events.erase(listener)
	elif subscriptions.has(event_key):
		subscriptions[event_key].erase(listener)

	# MEMO: If a listener has been removed,
	# this implementation will not remove it from published_async events. 


static func publish(event_key, payload = null)->void:
	"""
	Publishes the given event_key and payload.
	Subscribers to event_key will have their event_published methods called.
	"""
	var invalid_listeners = []
	var called = []

	if subscriptions.has(event_key):
		var listeners = subscriptions[event_key]
		for listener in listeners:
			if is_valid(listener):
				listener.call(event_handler_name, event_key, payload)
				called.append(listener)
			else:
				invalid_listeners.append(listener)

	for listener in all_events:
		if !called.has(listener):
			if is_valid(listener):
				listener.call(event_handler_name, event_key, payload)
			else:
				invalid_listeners.append(listener)

	# publish event to all valid listeners.

	# unsubscribe invalid listeners
	for invalid_listener in invalid_listeners:
		unsubscribe(invalid_listener)


static func publish_to_random(event_key:String, payload)->void:
	"""
	Publish an event to a single randomly-chosen subscriber
	"""
	if !subscriptions.has(event_key):
		return

	var listeners = subscriptions[event_key]
	if listeners.size() == 0:
		return

	var listener = listeners[randi_range(0, listeners.size()-1)]
	if is_valid(listener):
		listener.call(event_handler_name, event_key, payload)
	# MEMO: Handlers may not be invoked if the listener is invalid.


static func subscribe_instant(listener, event_key)->void:
	"""
	Subscribes listener to the given instant event_key.
	"""
	if !is_a_listener(listener, instant_event_hanlder_name):
		# Invalid object or No method to call
		return
	
	var listeners = instant_subscriptions.get_or_add(event_key, [])
	if !listeners.has(listener):
		listeners.append(listener)


static func unsubscribe_instant(listener, event_key = null)->void:
	"""
	Unsubscribes listener from instant event_key, or all event_keys if not supplied
	"""
	if event_key==null:
		for listeners in instant_subscriptions.values():
			listeners.erase(listener)
	elif instant_subscriptions.has(event_key):
		instant_subscriptions[event_key].erase(listener)


static func publish_instant(event_key, payload)->Array:
	"""
	Publish the given instant event key to all listeners and return an array of their responses
	"""
	var result = []
	var invalid_listeners = []

	if !instant_subscriptions.has(event_key):
		return result
	var listeners = instant_subscriptions[event_key]
	for listener in listeners:
		if is_valid(listener):
			result.append(listener.call(instant_event_hanlder_name, event_key, payload))
		else:
			invalid_listeners.append(listener)

	# unsubscribe invalid listeners
	for invalid_listener in invalid_listeners:
		unsubscribe_instant(invalid_listener)

	return result


static func publish_async(event_key, payload)->void:
	"""
	Queue the given event for async publishing. PubSub.process() MUST be called for this to work!
	"""
	var calling = []

	if subscriptions.has(event_key):
		var listeners = subscriptions[event_key]
		for listener in listeners:
			if is_valid(listener):
				# MEMO: published_async is a FIFO.
				published_async.push_front([listener, event_key, payload])
				calling.append(listener)

	for listener in all_events:
		if is_valid(listener) and !calling.has(listener):
			published_async.push_front([listener, event_key, payload])


static func process_async()->bool:
	"""
	Process the next outstanding async event, if any.
	
	process only one event per call.
	return false, if there is no async event.
	"""
	if published_async.size()==0:
		return false

	var arr = published_async.pop_back() as Array
	var listener = arr[0]
	var event_key = arr[1]
	var payload = arr[2]
	if is_valid(listener):
		listener.call(event_handler_name, event_key, payload)

	return published_async.size() > 0


static func process_async_all()->void:
	while process_async():
		pass


static func register_service(service_id:int, provider)->void:
	"""
	Registers a service for the given int service_id
	"""
	services[service_id] = provider


static func get_service(service_id:int):
	"""
	Returns the service registered under the given int service_id
	"""
	if services.has(service_id):
		return services[service_id]

	return null


static func clear()->void:
	"""
	Clears all event subscriptions
	"""
	subscriptions.clear()
	instant_subscriptions.clear()
	published_async.clear()
	all_events.clear()
	services.clear()


static func clear_instant_events()->void:
	"""
	Clears all instant event subscriptions
	"""
	instant_subscriptions.clear()
