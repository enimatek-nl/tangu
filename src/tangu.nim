import json, dom
from strutils import split, parseInt

#[
TODOS:
- Fix the -node- af derective replaces or updates (grabs the incorrect ones now when doing eg. two repeats in one parent node)
- Fix scope from cache (make a lifecycle like init and hide / view )
- Introduce a more central way of configuring the 'root' scope ?
]#

type
    Troute = tuple[path: string, controller: string]

    Tangu* = ref object
        directives: seq[Tdirective]
        controllers: seq[Tcontroller]
        routes: seq[Troute]
        root: Node
        scope: Tscope

    Tdirective* = ref object
        name*: string
        callback*: proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending)

    Tsubscription* = ref object
        name*: string
        callback*: proc(scope: Tscope, value: JsonNode)
        last: string

    TLifecycle* = enum
        Created, Resumed, Destroyed

    Tcontroller* = ref object
        name*: string
        view*: string
        work*: proc(scope: Tscope, lifecycle: Tlifecycle)
        root: Node
        scope: Tscope

    Tmethod* = tuple[n: string, f: proc(scope: Tscope)]

    Tpending = ref object
        list: seq[proc()]

    Tscope* = ref object
        model*: JsonNode
        methods*: seq[Tmethod]
        children: seq[Tscope]
        parent: Tscope
        subscriptions: seq[Tsubscription]

#
# Scope object
#

proc subscribe(self: Tscope, subscription: Tsubscription) =
    self.subscriptions.add(subscription)

proc digest*(self: Tscope) =
    for subscription in self.subscriptions:
        let splt = subscription.name.split(".")
        if not self.model{splt}.isNil:
            if subscription.last != $self.model{splt}:
                subscription.last = $self.model{splt}
                subscription.callback(self, self.model{splt})
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
    result = Tscope(parent: p, model: %*{})
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
    for route in self.routes:
        if route.path == path:
            let controller = self.controller(route.controller)
            if controller.scope.isNil():
                controller.scope = newScope(self.scope)
                controller.work(controller.scope, Tlifecycle.Created)
                controller.root = self.root.cloneNode(true)
                self.root.parentNode.appendChild(controller.root)
            else:
                controller.work(controller.scope, Tlifecycle.Resumed)
            # (re)render the view.
            controller.root.innerHTML = controller.view
            self.finish(controller.scope, controller.root)
            #
            self.root.style.display = "none"
            controller.root.style.display = "block"
            self.root = controller.root
            #self.root.parentNode.replaceChild(self.root, controller.root)
            # clone the current view
            # let elem = document.createElement("div")
            # elem.innerHTML = self.root.innerHTML
            # elem.style.animation = "fadeout 0.5s" # default animation
            # elem.addEventListener("animationend", proc (ev: Event) =
            # render the new view
            #     self.root.style.visibility = "visible"
            #     self.root.innerHTML = controller.view
            #     self.finish(scope, self.root)
            #     elem.remove()
            # )
            # self.root.style.visibility = "hidden"
            # clean up the mess
            break

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
            from {opacity: 1;}
            to {opacity: 0;}
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
                let splt = valueOf.split(".")
                if not scope.model{splt}.isNil() and (scope.model{splt}.kind == JBool or scope.model{splt}.kind == JInt):
                    if (scope.model{splt}.kind == JBool and scope.model{splt}.to(bool)) or (scope.model{splt}.kind == JInt and scope.model{splt}.to(int) > 0):
                        if not active:
                            parent.appendChild(node)
                            active = true
                    else:
                        if active:
                            parent.removeChild(node)
                            active = false

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
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
                let splt = valueOf.split(".")
                if not scope.model{splt}.isNil():
                    if scope.model{splt}.kind == JInt:
                        scope.model{splt}.num = parseInt($elem.value)
                    elif scope.model{splt}.kind == JString:
                        scope.model{splt}.str = $elem.value
                    elif scope.model{splt}.kind == JBool:
                        scope.model{splt}.bval = elem.checked
                scope.digest()

    )

proc tngModel*(): Tdirective =
    Tdirective(name: "tng-model", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            node.onkeyup = proc (event: Event) =
                let splt = valueOf.split(".")
                if not scope.model{splt}.isNil():
                    if scope.model{splt}.kind == JString:
                        scope.model{splt}.str = $node.value
                    elif scope.model{splt}.kind == JBool:
                        scope.model{splt}.bval = ($node.value == "true")
                scope.digest()

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
                if value.kind == JString: node.value = value.to(string)
                else: node.value = $value
            )
            )
    )

proc tngBind*(): Tdirective =
    Tdirective(name: "tng-bind", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
                if value.kind == JString: node.innerHTML = value.to(string)
                else: node.innerHTML = $value
            )
            )

            let splt = valueOf.split(".")
            if not scope.model{splt}.isNil():
                if scope.model{splt}.kind == JArray: node.innerHTML = scope.model{splt}.to(string)
                else: node.innerHTML = $scope.model{splt}
    )

proc tngRepeat*(): Tdirective =
    Tdirective(name: "tng-repeat", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            let parts = valueOf.split(" in ")
            let parentNode = node.parentNode
            var scopes: seq[Tscope] = @[]

            proc render(arr: JsonNode, firstRun: bool) =
                if not arr.isNil() and arr.kind == JArray:
                    var nominated: seq[Node] = @[]
                    for child in parentNode.children:
                        if child.hasAttribute("tng-repeat") or child.hasAttribute("tng-repeat-item"):
                            nominated.add(child)

                    let work = proc () =
                        for n in nominated:
                            parentNode.removeChild(n)

                        for s in scopes: s.destroy() # clean traces of the previous scopes
                        scopes = @[]

                        for item in arr.to(seq[JsonNode]):
                            let clone = node.cloneNode(true)
                            clone.removeAttribute("tng-repeat")
                            clone.setAttribute("tng-repeat-item", "")
                            parentNode.appendChild(clone)

                            let child_scope = scope.clone()
                            scopes.add(child_scope)
                            child_scope.model = %*{parts[0]: item}

                            self.compile(child_scope, clone, Tpending())

                    if firstRun:
                        pending.list.add(work)
                    else:
                        work()


            scope.subscribe(Tsubscription(name: parts[1], callback: proc (scope: Tscope, value: JsonNode) =
                render(value, false)
            ))

            let splt = parts[1].split(".") # collectionName
            if not scope.model{splt}.isNil():
                render(scope.model{splt}, true)
    )
