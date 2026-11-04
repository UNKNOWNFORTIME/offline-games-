class_name Pool
extends RefCounted
## Generic node pool. Nodes are created up front (prewarm) and recycled;
## when the pool is exhausted the oldest active node is reused, so there is
## never an instantiate()/queue_free() in the gameplay hot loop.

static var _registry: Array = []

var pool_name: String = ""
var max_size: int = 32
var _factory: Callable
var _parent: Node
var _free: Array[Node] = []
var _active: Array[Node] = []


func _init(p_name: String, factory: Callable, parent: Node, prewarm: int = 8, p_max: int = 32) -> void:
	pool_name = p_name
	_factory = factory
	_parent = parent
	max_size = p_max
	for i: int in prewarm:
		var n: Node = _create()
		_free.append(n)
	_registry.append(weakref(self))


func _create() -> Node:
	var n: Node = _factory.call()
	_parent.add_child(n)
	_hide(n)
	return n


func acquire() -> Node:
	var n: Node
	if _free.size() > 0:
		n = _free.pop_back()
	elif _active.size() + _free.size() < max_size:
		n = _create()
	else:
		n = _active.pop_front()
	_active.append(n)
	if n is Node3D:
		(n as Node3D).visible = true
	elif n is CanvasItem:
		(n as CanvasItem).visible = true
	return n


func release(n: Node) -> void:
	var i: int = _active.find(n)
	if i == -1:
		return
	_active.remove_at(i)
	_hide(n)
	_free.append(n)


func release_all() -> void:
	while _active.size() > 0:
		release(_active[_active.size() - 1])


func active_count() -> int:
	return _active.size()


func active() -> Array[Node]:
	return _active


func _hide(n: Node) -> void:
	if n is Node3D:
		(n as Node3D).visible = false
	elif n is CanvasItem:
		(n as CanvasItem).visible = false


static func total_active() -> int:
	var total: int = 0
	for w: Variant in _registry:
		var p: Pool = (w as WeakRef).get_ref() as Pool
		if p != null:
			total += p.active_count()
	return total
