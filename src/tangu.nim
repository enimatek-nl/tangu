import dom, jsffi
from strutils import split, parseInt

#
# Extra DOM/JS bindings
#
proc jsIsArray*(x: JsObject): bool {.importcpp: "Array.isArray(#)".}
proc jsStringify*(x: JsObject): cstring {.importcpp: "JSON.stringify(#)".}

proc set*(self: JsObject, path: string, val: JsObject): bool =
    ## Look for the `path` in the `JsObject` and overwrite the value
    var s = self
    let r = path.split(".")
    for i, v in r:
        if s.hasOwnProperty(v):
            if i == r.len - 1:
                s[v] = val
            else:
                s = s[v]
        else:
            return false
    return true

proc get*(self: JsObject, path: string): JsObject =
    ## Look for the `path` in the `JsObject` and return the value as `JsObject`
    var s = self
    for v in path.split("."):
        if s.hasOwnProperty(v):
            s = s[v]
        else:
            return
    result = s

proc add*[T](self: JsObject, path: string, item: T) =
    ## Easy way to add an object into the `JsObject` defined array
    var objs = self.get(path).to(seq[T])
    objs.add(item)
    discard self.set(path, toJs objs)

proc delete*(self: JsObject, path: string, index: int) =
    ## Easy way to remove an index from the `JsObject` defined array
    var objs = self.get(path).to(seq[JsObject])
    objs.delete(index)
    discard self.set(path, toJs objs)

#
# Tangu types
#
type
    Tauth = proc(self: Tguard, cname: string, scope: Tscope): bool

    Tguard* = ref object
        hash*: string
        work: Tauth

    Troute = tuple[p: string, c: string, g: Tguard]

    Tmethod = tuple[n: string, f: proc(scope: Tscope)]

    Tangu* = ref object
        directives: seq[Tdirective]
        controllers: seq[Tcontroller]
        routes: seq[Troute]
        root: Node
        previous: Node
        scope: Tscope

    Tpending = ref object
        list: seq[proc()]

    Tdirective = ref object
        name: string
        callback*: proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending)

    Tsubscription = ref object
        name: string
        callback: proc(scope: Tscope, value: JsObject)
        last: cstring

    TLifecycle* = enum
        Created, Resumed

    Twork = proc(scope: Tscope, lifecycle: Tlifecycle)

    Tcontroller = ref object
        name: string
        view: string
        work: Twork
        scope: Tscope

    Tscope* = ref object
        model*: JsObject
        methods*: seq[Tmethod]
        children: seq[Tscope]
        parent: Tscope
        subscriptions: seq[Tsubscription]

#
# Route, Conroller, etc..
#

proc newMethod*(name: string, function: proc (scope: Tscope)): Tmethod =
    result = (n: name, f: function)

proc newController*(name: string, staticView: static string, work: Twork): Tcontroller =
    result = Tcontroller(name: name, view: staticView, work: work)

proc newRoute*(path: string, controller: string, guard: Tguard = nil): Troute =
    result = (p: path, c: controller, g: guard)

proc newGuard*(function: Tauth): Tguard =
    result = Tguard(work: function)

#
# Scope object
#

proc subscribe(self: Tscope, subscription: Tsubscription) =
    self.subscriptions.add(subscription)

proc digest*(self: Tscope) =
    for subscription in self.subscriptions:
        let v = self.model.get(subscription.name)
        if not v.isNil:
            if subscription.last != jsStringify(v):
                subscription.last = jsStringify(v)
                subscription.callback(self, v)
    if not self.parent.isNil:
        self.parent.digest()

proc clone*(self: Tscope): Tscope =
    result = Tscope(parent: self)
    self.children.add(result)

proc destroy*(self: Tscope) =
    let i = self.parent.children.find(self)
    if i != -1:
        self.parent.children.delete(i)

proc exec(self: Tscope, n: string, s: Tscope) =
    for m in self.methods:
        if m.n == n:
            m.f(s)
            return
    if not self.parent.isNil:
        self.parent.exec(n, s)

proc root*(self: Tscope): Tscope =
    if not self.parent.isNil:
        return self.parent.root()
    else:
        return self

proc newScope*(p: Tscope = nil): Tscope =
    result = Tscope(parent: p, model: JsObject{})
    if not p.isNil:
        p.children.add(result)

#
# Tangu object
#

proc exec(self: Tangu, scope: Tscope, node: Node, pending: Tpending) =
    for attr in node.attributes:
        for dir in self.directives:
            if dir.name == attr.nodeName:
                dir.callback(self, scope, node, $attr.nodeValue, pending)

proc compile(self: Tangu, scope: Tscope, child: Node, pending: Tpending) =
    self.exec(scope, child, pending)
    for node in child.children:
        self.compile(scope, node, pending)

proc finish(self: Tangu, scope: Tscope, parent: Node) =
    let pending = Tpending() # execute this after parent node is done setting up.
    for node in parent.children:
        self.compile(scope, node, pending)
    # process all pending (out of for-loop) actions
    for pen in pending.list:
        pen()
    scope.digest()

proc controller(self: Tangu, id: string): Tcontroller =
    for controller in self.controllers:
        if controller.name == id: return controller

proc navigate*(self: Tangu, path: string) =
    block foundController:
        for route in self.routes:
            if route.p == path:
                # get the controller and refresh the scope
                let controller = self.controller(route.c)

                # check the controller guard first
                if not route.g.isNil and not route.g.work(route.g, controller.name, self.scope):
                    window.location.hash = route.g.hash
                    break foundController

                # prepare the scope
                var lifecycle = Tlifecycle.Created
                if controller.scope.isNil():
                    controller.scope = newScope(self.scope)
                else:
                    lifecycle = Tlifecycle.Resumed

                # continue preparing the scope
                controller.work(controller.scope, lifecycle)

                # Re create the controllers element view based on the parent node
                let elem = self.root.cloneNode(true)
                elem.innerHTML = controller.view
                elem.style.position = "absolute" #/-- better css solution for this?
                elem.style.width = "100%" #       |
                elem.style.height = "100%" #      |
                elem.style.animation = "fadein 0.5s" # ----------\
                if not self.previous.isNil(): #                  |
                    let previous = self.previous #              \/
                    previous.style.animation = "fadeout 0.5s" # these animation can be configured later?
                    elem.addEventListener("animationend", proc (ev: Event) =
                        # clean up old elements
                        if ev.target.hasAttribute("tng-router"): previous.remove()
                    )
                self.root.parentNode.insertBefore(elem, self.root)
                self.finish(controller.scope, elem)
                # refer to the previous controller for clean/animation etc. purposes
                self.previous = elem
                break foundController
        echo "!! no controller found for path: " & path

proc bootstrap*(self: Tangu) =
    # setup hashbang navigation
    window.addEventListener("hashchange", proc (ev: Event) =
        var hash = $(window.location.hash)
        echo "hashchange: " & hash
        hash = hash.substr(2, hash.len - 1)
        self.navigate(hash)
    )
    # setup basic animations (TODO for later)
    let style = document.createElement("style")
    style.innerHTML = """
        @keyframes fadeout {
            from {opacity: 0.5;}
            to {opacity: 0;}
        }
        @keyframes fadein {
            from {opacity: 0.2; margin-top: 4%;}
            to {opacity: 1; margin-top: 0%;}
        }
        @keyframes slidein {
          from {margin-left: 100%;}
          to {margin-left: 0%;}
        }
    """
    document.head.appendChild(style);
    self.scope = newScope()
    self.finish(self.scope, document.children[0])
    echo "Done bootstrapping tangu-spa"

proc newTangu*(directives: seq[Tdirective], controllers: seq[Tcontroller], routes: seq[Troute]): Tangu =
    Tangu(directives: directives, controllers: controllers, routes: routes)

#
# Bindings
#

proc tngIf*(): Tdirective =
    Tdirective(name: "tng-if", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            let parent = node.parentNode
            var active = true

            let check = proc () =
                let jsval = scope.model.get(valueOf)
                if not jsval.isNil and jsval.to(bool):
                    if not active:
                        parent.appendChild(node)
                        active = true
                else:
                    if active:
                        parent.removeChild(node)
                        active = false

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) =
                check()
            )
            )

            pending.list.add(check)
    )

proc tngClick*(): Tdirective =
    Tdirective(name: "tng-click", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            node.onclick = proc (event: Event) =
                scope.exec(valueOf, scope)
                scope.digest()
    )

proc tngRouter*(): Tdirective =
    Tdirective(name: "tng-router", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            self.root = node
            pending.list.add(proc () =
                window.location.hash = "#!" & valueOf
                self.navigate(valueOf)
            )
    )

proc tngChange*(): Tdirective =
    Tdirective(name: "tng-change", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            node.onchange = proc (event: Event) =
                let elem = Element(node)
                if scope.model.set(valueOf, toJs(elem.value)):
                    scope.digest()
                else:
                    echo valueOf & " not found"
    )

proc tngModel*(): Tdirective =
    Tdirective(name: "tng-model", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            node.onkeyup = proc (event: Event) =
                if scope.model.set(valueOf, toJs(node.value)):
                    scope.digest()

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) =
                #if value.kind == JString: node.value = value.to(string)
                #else: node.value = $value
                node.value = value.to(cstring)
            )
            )
    )

proc tngBind*(): Tdirective =
    Tdirective(name: "tng-bind", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) =
                #if value.kind == JString: node.innerHTML = value.to(string)
                #else: node.innerHTML = $value
                node.value = value.to(cstring)
            )
            )

            let obj = scope.model.get(valueOf)
            if not obj.isNil:
                node.innerHTML = obj.to(cstring)
    )

proc tngRepeat*(): Tdirective =
    Tdirective(name: "tng-repeat", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            let parts = valueOf.split(" in ")
            let parentNode = node.parentNode
            var scopes: seq[Tscope] = @[]

            proc render(arr: JsObject, firstRun: bool) =
                if not arr.isNil and jsIsArray(arr):
                    var nominated: seq[Node] = @[]
                    for child in parentNode.children:
                        if child.hasAttribute("tng-repeat") or child.hasAttribute("tng-repeat-item"):
                            nominated.add(child)

                    let work = proc () =
                        for n in nominated:
                            parentNode.removeChild(n)

                        for s in scopes: s.destroy() # clean traces of the previous scopes
                        scopes = @[]

                        for item in arr.to(seq[JsObject]):
                            let clone = node.cloneNode(true)
                            clone.removeAttribute("tng-repeat")
                            clone.setAttribute("tng-repeat-item", "")
                            parentNode.appendChild(clone)

                            let child_scope = scope.clone()
                            scopes.add(child_scope)

                            child_scope.model = JsObject{$parts[0]: item}

                            self.compile(child_scope, clone, Tpending())

                    if firstRun:
                        pending.list.add(work)
                    else:
                        work()


            scope.subscribe(Tsubscription(name: parts[1], callback: proc (scope: Tscope, value: JsObject) =
                render(value, false)
            ))

            let obj = scope.model.get(parts[1])
            if not obj.isNil:
                render(obj, true)
    )
