"""
PubSub test

This is a rather messy test implementation for the PubSub class.
As I am new to GDScript, any advice would be greatly appreciated.
"""
extends GutTest

var PubSub = load('res://addons/godot-pub-sub/addons/pub-sub/PubSub.gd')

class TestListener:
	extends Object

	var event_count : int = 0
	var instant_count : int = 0
	var last_key = ""
	var last_payload = null
	var last_instant_key = ""
	var last_instant_payload = null
	var name = "" # this class is not based on Node

	func event_published(event_key, payload):
		last_key = event_key
		last_payload = payload
		event_count += 1

	func instant_event_published(event_key, payload):
		last_instant_key = event_key
		last_instant_payload = payload
		instant_count +=1
		return name

class TestListenerNode:
	extends Node

	var event_count : int = 0
	var instant_count : int = 0
	var last_key = ""
	var last_payload = null
	var last_instant_key = ""
	var last_instant_payload = null

	func event_published(event_key, payload):
		last_key = event_key
		last_payload = payload
		event_count += 1

	func instant_event_published(event_key, payload):
		last_instant_key = event_key
		last_instant_payload = payload
		instant_count +=1
		return name

var l1 = null
var l2 = null
var l3 = null
var n1 = null
var n2 = null
var n3 = null

const key1 = 'event 1'
const key2 = 'event 2'
const key3 = 'event 3'
const payload1 = { "name": "payload 1" }
const payload2 = { "name": "payload 2" }
const payload3 = { "name": "payload 3" }

func before_each():
	PubSub.clear()
	l1 = TestListener.new()
	l2 = TestListener.new()
	l3 = TestListener.new()
	l1.name = 'l1'
	l2.name = 'l2'
	l3.name = 'l3'
	n1 = TestListenerNode.new()
	n2 = TestListenerNode.new()
	n3 = TestListenerNode.new()
	n1.set_name('n1')
	n2.set_name('n2')
	n3.set_name('n3')

func after_each():
	if is_instance_valid(l1): l1.free()
	if is_instance_valid(l2): l2.free()
	if is_instance_valid(l3): l3.free()
	if is_instance_valid(n1): n1.free()
	if is_instance_valid(n2): n2.free()
	if is_instance_valid(n3): n3.free()
	l1 = null
	l2 = null
	l3 = null
	n1 = null
	n2 = null
	n3 = null

func test_pubsub_class():
	assert_true(PubSub != null, 'PubSub is loaded.')

func test_subscribe_all():
	PubSub.subscribe(l1)
	# no handler object - won't subscribe
	PubSub.subscribe(Object.new()) # no effect
	PubSub.subscribe(null) # no effect
	assert_eq(PubSub.all_events.size(), 1, 'subscribe all events')
	assert_same(PubSub.all_events[0], l1, 'event listener is testlistener.')
	PubSub.publish(key1, null)
	PubSub.publish(key2, null)
	assert_eq(l1.event_count, 2, 'event_published will be called twice.')

func test_subscribe_event():
	PubSub.subscribe(Object.new(), key1) # no effect
	PubSub.subscribe(null, key1) # no effect
	PubSub.subscribe(l1, key1)
	PubSub.subscribe(l2, key2)
	assert_eq(PubSub.subscriptions[key1].size(), 1, 'number of key1 subscriber is 1')
	assert_eq(PubSub.subscriptions[key2].size(), 1, 'number of key2 subscriber is 1')

	assert_eq(l1.event_count, 0, 'handler for key1 is not called yet.')
	assert_eq(l2.event_count, 0, 'handler for key2 is not called yet.')
	PubSub.publish(key1, payload1)
	assert_eq(l1.event_count, 1, 'handler for key1 is called once.')
	assert_eq(l1.last_key, key1, 'published key is correct.')
	assert_same(l1.last_payload, payload1, 'published payload is correct.')
	assert_eq(l2.event_count, 0, 'handler for key2 is not called.')

func test_subscribe_invalid_listener():
	PubSub.subscribe(l1, key1)
	PubSub.subscribe(n1, key1)
	assert_eq(l1.event_count, 0, 'handler is not called yet.')
	assert_eq(n1.event_count, 0, 'handler is not called yet.')
	assert_eq(PubSub.subscriptions[key1].size(), 2, '2 handlers.')

	l1.free()
	# l1-freed, cannot catch an event.
	# n1 catch an event.
	PubSub.publish(key1, payload1)
	assert_eq(n1.event_count, 1, 'handler is called once.')
	assert_eq(PubSub.subscriptions[key1].size(), 1, 'auto removed 1 handler.')

	n1.queue_free()
	# l1-freed and removed.
	# n1-queued for deletion
	PubSub.publish(key1, payload1)
	assert_eq(n1.event_count, 1, 'handler is not called again.')
	# n1 removed.
	assert_eq(PubSub.subscriptions[key1].size(), 0, 'auto removed.')

func test_unsubscribe():
	PubSub.subscribe(l1, key1)
	PubSub.subscribe(l1)
	assert_eq(l1.event_count, 0, 'handler is not called yet.')

	PubSub.publish(key1, payload1)
	assert_eq(l1.event_count, 1, 'handler is called once.')

	PubSub.unsubscribe(l1, key1)
	PubSub.publish(key1, payload1)
	assert_eq(l1.event_count, 2, 'handler is called for all events handler.')

	PubSub.unsubscribe(l1)
	PubSub.publish(key1, payload1)
	assert_eq(l1.event_count, 2, 'handler is not called again.')

func test_unsubscribe_all():
	PubSub.subscribe(l1, key1)
	PubSub.subscribe(l1, key2)
	PubSub.subscribe(l1)
	assert_eq(l1.event_count, 0, 'handler is not called yet.')
	PubSub.publish(key1, payload1)
	PubSub.publish(key2, payload2)
	assert_eq(l1.event_count, 2, 'handler is called twice.')
	PubSub.unsubscribe(l1) # unsubscribe all.
	PubSub.publish(key1, payload1)
	PubSub.publish(key2, payload2)
	assert_eq(l1.event_count, 2, 'handler is not called again.')

func test_publish_random():
	# no handlers
	PubSub.publish_to_random(key1, payload1)

	# no event_key handler
	PubSub.subscribe(l1, key1)
	PubSub.unsubscribe(l1, key1)
	PubSub.publish_to_random(key1, payload1)
	assert_true(true, 'no error')

	# if only one handler subscribed, call the handler.
	PubSub.subscribe(l1, key1)
	PubSub.publish_to_random(key1, payload1)
	assert_eq(l1.event_count, 1, 'once called.')
	PubSub.publish_to_random(key1, payload1)
	assert_eq(l1.event_count, 2, 'twice called.')

	PubSub.subscribe(l2, key1)
	PubSub.subscribe(l3, key1)
	PubSub.unsubscribe(l1, key1)
	for i in range(100):
		PubSub.publish_to_random(key1, payload1)
	assert_true(l2.event_count > 0, 'published to l2')
	assert_true(l3.event_count > 0, 'published to l3')
	assert_eq(l2.event_count + l3.event_count, 100, 'called 100 times')

func test_subscribe_instant():
	var result = PubSub.publish_instant(key1, payload1)
	assert_eq_deep(result, [])

	PubSub.subscribe_instant(l1, key1)
	PubSub.unsubscribe_instant(l1, key1)
	result = PubSub.publish_instant(key1, payload1)
	assert_eq_deep(result, [])

	PubSub.subscribe_instant(Object.new(), key1) # no effect
	PubSub.subscribe_instant(null, key1) # no effect
	PubSub.subscribe_instant(l1, key1)
	PubSub.subscribe_instant(l2, key2)
	PubSub.subscribe_instant(l3, key1)
	assert_eq(PubSub.instant_subscriptions[key1].size(), 2, 'number of key1 subscriber is 1')
	assert_eq(PubSub.instant_subscriptions[key2].size(), 1, 'number of key2 subscriber is 1')

	assert_eq(l1.instant_count, 0, 'handler for key1 is not called yet.')
	assert_eq(l2.instant_count, 0, 'handler for key2 is not called yet.')
	result = PubSub.publish_instant(key1, payload1)
	assert_eq_deep(result, ["l1", "l3"])
	l1.free()
	result = PubSub.publish_instant(key1, payload1)
	assert_eq_deep(result, ["l3"])
	assert_eq(PubSub.instant_subscriptions[key1].size(), 1, 'auto remove invalid handlers.')
	
	PubSub.unsubscribe_instant(l2, key2)
	PubSub.unsubscribe_instant(l3)
	assert_eq(PubSub.instant_subscriptions[key1].size(), 0, 'no handlers')
	assert_eq(PubSub.instant_subscriptions[key2].size(), 0, 'no handlers')
	
func test_publish_async():
	PubSub.publish_async(key1, payload1)
	assert_eq(PubSub.published_async.size(), 0, "no async event has been issued.")

	PubSub.subscribe(Object.new(), key1) # no effect
	PubSub.subscribe(null, key1) # no effect
	PubSub.subscribe(l1, key1)
	PubSub.subscribe(l2, key2)
	PubSub.subscribe(l3)

	assert_eq(PubSub.subscriptions[key1].size(), 1, 'number of key1 subscriber is 1')
	assert_eq(PubSub.subscriptions[key2].size(), 1, 'number of key2 subscriber is 1')
	assert_eq(PubSub.all_events.size(), 1, 'number of all event subscriber is 1')

	PubSub.publish_async(key1, payload1)
	assert_eq(PubSub.published_async.size(), 2, "two async events have been issued.")

	assert_eq(l1.event_count, 0, 'not processed a event for l1 yet.')
	assert_eq(l3.event_count, 0, 'not processed a event for l3 yet.')
	assert_true(PubSub.process_async(), 'process 1 async event.')
	assert_eq(l1.event_count, 1, 'call handler once for l1')
	assert_eq(l3.event_count, 0, 'not processed a event for l3 yet.')
	assert_false(PubSub.process_async(), 'process 1 async event.')
	assert_eq(l1.event_count, 1, 'not increased for l1')
	assert_eq(l3.event_count, 1, 'call handler once for l3')

	PubSub.publish_async(key1, payload1)
	PubSub.process_async_all()
	assert_eq(l1.event_count, 2, 'call handler once for l1')
	assert_eq(l3.event_count, 2, 'call handler once for l3')
