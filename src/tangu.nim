import dom, jsffi, tables, sugar, asyncjs
from strutils import split, parseInt

#
# Helpfull DOM / JS bindings
#
proc jsHasServiceworker(): bool {.importcpp: "'serviceWorker' in navigator".}
proc jsIsArray*(x: JsObject): bool {.importcpp: "Array.isArray(#)".}
proc jsStringify*(x: JsObject): cstring {.importcpp: "JSON.stringify(#)".}
proc jsTimestamp*(): cint {.importcpp: "Date.now()".}
proc jsHexId*(): cstring {.importcpp: "Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)".}
proc genId*(): string =
    result = $jsHexId() & "-" & $jsHexId() & "-" & $jsHexId() & "-" & $jsHexId()
    
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

    Tlifecycle* = enum
        Created, Resumed, Initialized

    Twork = (scope: Tscope, lifecycle: Tlifecycle) -> Future[void]

    Tcontroller = ref object
        name: string
        view: string
        work: Twork
        scope: Tscope

    Tscope* = ref object
        model*: JsObject
        children: seq[Tscope]
        parent: Tscope
        subscriptions: seq[Tsubscription]

#
# Route, Conroller, etc..
#

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

proc exec(self: Tscope, v: string, s: Tscope, n: Node) =
    if not self.model.get(v).isNil:
        # call the js binded function with a local-scope and a ref to the node
        var f = self.model.get(v).to(proc(scolp: Tscope, node: Node))
        f(s, n)
    elif not self.parent.isNil:
        self.parent.exec(v, s, n)

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

proc navigate*(self: Tangu, path: string) {.async.} =
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
                if controller.scope.isNil():
                    controller.scope = newScope(self.scope)
                    await controller.work(controller.scope, Tlifecycle.Created)

                # continue preparing the scope
                await controller.work(controller.scope, Tlifecycle.Resumed)

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
                # run code after the view is part of the dom
                await controller.work(controller.scope, Tlifecycle.Initialized)
                break foundController
        echo "!! no controller found for path: " & path

proc bootstrap*(self: Tangu) =
    # setup hashbang navigation
    window.addEventListener("hashchange", proc (ev: Event) =
        var hash = $(window.location.hash)
        echo "hashchange: " & hash
        hash = hash.substr(2, hash.len - 1)
        discard self.navigate(hash)
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
            # replace the node with a placeholder to remember the position for ever
            let id = genId()
            let placeholder = document.createElement("template")
            placeholder.setAttribute("tng-id", id)
            parent.replaceChild(placeholder, node)
            var active = false

            let check = proc () =
                let jsval = scope.model.get(valueOf)
                if not jsval.isNil and jsval.to(bool):
                    if not active:
                        parent.insertBefore(node, placeholder)
                        active = true
                else:
                    if active:
                        parent.removeChild(node)
                        active = false

            scope.subscribe(Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) =
                check())
            )

            pending.list.add(check)
    )

proc tngClick*(): Tdirective =
    Tdirective(name: "tng-click", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            node.onclick = proc (event: Event) =
                scope.exec(valueOf, scope, node)
    )

proc tngRouter*(): Tdirective =
    Tdirective(name: "tng-router", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            self.root = node
            pending.list.add(proc () =
                window.location.hash = "#!" & valueOf
                discard self.navigate(valueOf)
            )
    )

proc tngChange*(): Tdirective =
    Tdirective(name: "tng-change", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            node.onchange = proc (event: Event) =
                scope.exec(valueOf, scope, node)
                #scope.digest()
    )

proc tngModel*(): Tdirective =
    Tdirective(name: "tng-model", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            # check if the value exists else just ignore all bindings
            let obj = scope.model.get(valueOf)
            if not obj.isNil:
                # some elements only have values onchange
                node.onchange = proc (event: Event) =
                    let elem = Element(node)
                    if elem.nodeName == "CHECKBOX" or elem.nodeName == "SELECT":
                        if scope.model.set(valueOf, toJs elem.value):
                            scope.digest()

                # inputs can better be handled by onkeyup
                node.onkeyup = proc (event: Event) =
                    if scope.model.set(valueOf, toJs(node.value)):
                        scope.digest()

                scope.subscribe(
                    Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) = node.value = value.to(cstring))
                )
    )

proc tngBind*(): Tdirective =
    Tdirective(name: "tng-bind", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            # check if the valueOf exists in the model - else skip
            let obj = scope.model.get(valueOf)
            if not obj.isNil:
                scope.subscribe(
                    Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsObject) = node.value = value.to(cstring))
                )
                node.innerHTML = obj.to(cstring)
    )

proc tngRepeat*(): Tdirective =
    Tdirective(name: "tng-repeat", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            let parts = valueOf.split(" in ")
            # keep track of the position and childern of the repeat by use of a placeholder and ids
            let id = genId()
            let placeholder = document.createElement("template")
            placeholder.setAttribute("tng-id", id)
            let parentNode = node.parentNode
            parentNode.replaceChild(placeholder, node)

            var scopes: seq[Tscope] = @[]

            proc render(arr: JsObject, firstRun: bool) =
                if not arr.isNil and jsIsArray(arr):
                    var nominated: seq[Node] = @[]
                    for child in parentNode.children:
                        if child.hasAttribute("tng-repeat") or child.hasAttribute("tng-repeat-item"):
                            if child == node or child.getAttribute("tng-id") == id: nominated.add(child)

                    let work = proc () =
                        for n in nominated:
                            parentNode.removeChild(n)

                        for s in scopes: s.destroy() # clean traces of the previous scopes
                        scopes = @[]

                        for item in arr.to(seq[JsObject]):
                            let clone = node.cloneNode(true)
                            clone.removeAttribute("tng-repeat")
                            clone.setAttribute("tng-repeat-item", "")
                            clone.setAttribute("tng-id", id)
                            parentNode.insertBefore(clone, placeholder)

                            let child_scope = scope.clone()
                            scopes.add(child_scope)

                            child_scope.model = JsObject{$parts[0]: item}

                            let child_pender = TPending()
                            self.compile(child_scope, clone, child_pender)
                            for p in child_pender.list:
                                p()

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

proc tngAttr*(): Tdirective =
    Tdirective(name: "tng-attr", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            var onlyWhen = true
            var parts = valueOf.split(" when ")
            if parts.len == 1:
                parts = valueOf.split(" is ")
                onlyWhen = true


            if parts.len == 2:
                # check if the model contains the parts - else skip this code
                let obj = scope.model.get(parts[1])
                if not obj.isNil:
                    proc handleAttr(v: JsObject) =
                        let b = v.to(bool)
                        if onlyWhen:
                            if b:
                                node.setAttribute(parts[0], "")
                            else:
                                node.removeAttribute(parts[0])
                        else:
                            node.setAttribute(parts[0], v.to(cstring))
                    # subscribe to the given value
                    scope.subscribe(Tsubscription(name: parts[1], callback: proc (scope: Tscope, value: JsObject) = handleAttr(value)))
                    # first run must be done 'pending'
                    pending.list.add(proc () = handleAttr(obj))
            else:
                echo "cannot parse '" & valueOf & "'"
    )
