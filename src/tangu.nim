import json, dom
from strutils import split

type
    Tangu* = ref object
        directives: seq[Tdirective]
        controllers: seq[Tcontroller]
        scopes: seq[tuple[n: string, s: Tscope]]
        root*: Node

    Tdirective* = ref object
        name*: string
        stopOn*: bool # stop on this directive (compile/controller) eg. router needs this
        callback*: proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending)

    Tsubscription* = ref object
        name*: string
        callback*: proc(scope: Tscope, value: JsonNode)
        last: string

    Tcontroller* = ref object
        name*: string
        view*: string
        construct*: proc(scope: Tscope)

    Tmethod* = tuple[n: string, f: proc(scope: Tscope)]

    Tpending = ref object
        list: seq[proc()]

    Tscope* = ref object
        model*: JsonNode
        methods*: seq[Tmethod]
        children: seq[Tscope]
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

proc clone*(self: Tscope): Tscope =
    result = Tscope()
    self.children.add(result)

#
# Tangu object
#

proc newScope(self: Tangu, name: string): Tscope =
    result = Tscope()
    self.scopes.add (n: name, s: result)

proc exec(self: Tangu, scope: Tscope, node: Node, pending: Tpending): bool =
    for attr in node.attributes:
        for dir in self.directives:
            if dir.name == attr.nodeName:
                echo "during exec of " & $attr.nodeName & " size is " & $scope.methods.len
                dir.callback(self, scope, node, $attr.nodeValue, pending)
                if dir.stopOn:
                    return false
    return true

proc compile(self: Tangu, scope: Tscope, child: Node, pending: Tpending): bool {.discardable.} =
    if self.exec(scope, child, pending):
        for node in child.children:
            if not self.compile(scope, node, pending):
                return false
        return true
    return false

proc finish(self: Tangu, scope: Tscope, parent: Node) =
    let pending = Tpending() # execute this after parent node is done setting up.
    for node in parent.children:
        self.compile(scope, node, pending)
    for pen in pending.list:
        pen()

proc pushPage*(self: Tangu, name: string) =
    block done:
        for ctrl in self.controllers:
            if ctrl.name == name:
                let scope = self.newScope(name)
                ctrl.construct(scope)
                self.root.innerHTML = ctrl.view
                self.finish(scope, self.root)
                break done

proc bootstrap*(self: Tangu) =
    let scope = self.newScope("root")
    self.finish(scope, document.children[0])
    echo "bootstrap is done."

proc newTangu*(directives: seq[Tdirective], controllers: seq[Tcontroller]): Tangu =
    Tangu(directives: directives, controllers: controllers)

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
                echo "recheck!"
                check()
            )
            )

            pending.list.add(check)
    )

proc tngClick*(): Tdirective =
    Tdirective(name: "tng-click", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            node.onclick = proc (event: Event) =
                for m in scope.methods:
                    if m.n == valueOf: m.f(scope)
                scope.digest()
    )

proc tngRouter*(): Tdirective =
    Tdirective(name: "tng-router", stopOn: true, callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            self.root = node
            self.pushPage(valueOf)
    )

proc tngModel*(): Tdirective =
    Tdirective(name: "tng-model", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            node.onkeyup = proc (event: Event) =
                let splt = valueOf.split(".")
                if not scope.model{splt}.isNil():
                    scope.model{splt}.str = $node.value
                scope.digest()

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
                node.value = value.to(string))
            )
    )

proc tngBind*(): Tdirective =
    Tdirective(name: "tng-bind", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =

            scope.subscribe(
                Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
                node.innerHTML = value.to(string))
            )

            let splt = valueOf.split(".")
            if not scope.model{splt}.isNil():
                node.innerHTML = scope.model{splt}.to(string)
    )

proc tngRepeat*(): Tdirective =
    Tdirective(name: "tng-repeat", callback:
        proc(self: Tangu, scope: Tscope, node: Node, valueOf: string, pending: Tpending) =
            let parts = valueOf.split(" in ")
            let parentNode = node.parentNode

            proc render(arr: JsonNode, firstRun: bool) =
                if arr.kind == JArray:
                    var nominated: seq[Node] = @[]
                    for child in parentNode.children:
                        if child.hasAttribute("tng-repeat") or child.hasAttribute("tng-repeat-item"):
                            nominated.add(child)

                    let work = proc () =
                        for n in nominated:
                            parentNode.removeChild(n)

                        for item in arr.to(seq[JsonNode]):
                            let clone = node.cloneNode(true)
                            clone.removeAttribute("tng-repeat")
                            clone.setAttribute("tng-repeat-item", "")
                            parentNode.appendChild(clone)
                            let child_scope = scope.clone()
                            child_scope.model = %* {parts[0]: item}
                            self.compile(child_scope, clone, Tpending())

                    if firstRun:
                        pending.list.add(work)
                    else:
                        work()


            scope.subscribe(Tsubscription(name: valueOf, callback: proc (scope: Tscope, value: JsonNode) =
                render(value, false)
            ))

            let splt = parts[1].split(".") # collectionName
            if not scope.model{splt}.isNil():
                render(scope.model{splt}, true)
    )
