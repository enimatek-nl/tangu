import asyncjs, sequtils, jsffi, dom, sugar, tangu, tangu/fetch, tangu/mediadevices, tangu/indexeddb

type
    Todo = ref object
        id: cstring
        content: cstring
        done: bool

    Extra = ref object
        text: cstring
        selected: bool

let loginController = newController(
    "login",
    staticRead("login.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

    scope.model.login_button = bindMethod proc (that: JsObject) {.async.} =
        scope.root().model.authenticated = true
        window.location.hash = "#!/"
)

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

    scope.model.todos = await indexedDB().getAll("todos")

    scope.model.show = false

    if lifecycle == Tlifecycle.Created:

        scope.model.intro = "click on the add button to navigate to the add controller"
        scope.model.selected = "abc"

        scope.model.extras = [
            Extra(text: "undone", selected: false),
            Extra(text: "done", selected: false),
            Extra(text: "all", selected: true)
        ]

        scope.model.new_filter = bindMethod proc (that: JsObject, scolp: Tscope, node: Node) {.async.} =
            let todos = (await indexedDB().getAll("todos")).to(seq[Todo])
            
            if $node.value == "undone":
                scope.model.todos = todos.filterIt(it.done == false)
            elif $node.value == "done":
                scope.model.todos = todos.filterIt(it.done == true)
            else:
                scope.model.todos = todos

            scope.digest()

        scope.model.start_camera = bindMethod proc (that: JsObject) {.async.} =
            let stream = await mediaDevices().getUserMedia(JsObject{video: true})
            let elem = document.getElementById("video")
            elem.setStream(stream)

        scope.model.del_button = bindMethod proc(that: JsObject, scolp: Tscope) {.async.} =
            let todo = scolp.model.todo.to(Todo)
            let ok = await indexedDB().delete("todos", todo.id)
            if ok:
                scope.model.todos = await indexedDB().getAll("todos")
                scope.digest()
        
        scope.model.check_todo = bindMethod proc(that: JsObject, scolp: Tscope) {.async.} =
            let todo = scolp.model.todo.to(Todo)
            scolp.model.todo.done = not scolp.model.todo.done
            discard await indexedDB().put("todos", toJs todo)
            
)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

    # reset the form input
    scope.model.done = false
    scope.model.content = ""

    if lifecycle == Tlifecycle.Created:
        scope.model.done_button = bindMethod proc(that: JsObject, scope: Tscope, node: Node) {.async.} =
            let todo = Todo(
                id: genId(),
                done: true,
                content: scope.model.content.to(cstring)
            )

            if await indexedDB().put("todos", toJs todo):
                window.location.hash = "#!/"
)

let auth = newGuard(proc (self: Tguard, cname: string, scope: Tscope): bool =
    # use 'authenticated' in the root scope to guard the controllers
    if scope.isNil or scope.root().model.authenticated.isNil or not scope.root().model.authenticated.to(bool):
        self.hash = "#!/login"
        return false
    else:
        return true
)

let tng = newTangu(
    @[
        tngIf(),
        tngAttr(),
        tngRepeat(),
        tngBind(),
        tngModel(),
        tngClick(),
        tngChange(),
        tngRouter()],
    @[
        loginController,
        viewTodosController,
        addTodoController],
    @[
        newRoute("/login", "login"),
        newRoute("/", "viewTodos", auth),
        newRoute("/add", "addTodo", auth)]
)
tng.bootstrap()
