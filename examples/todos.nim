import asyncjs, jsffi, dom, sugar, tangu, tangu/fetch, tangu/mediadevices, tangu/indexeddb

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
            Extra(text: "nested", selected: false),
            Extra(text: "repeat", selected: false),
            Extra(text: "tag", selected: true)
        ]

        scope.model.start_camera = bindMethod proc (that: JsObject) {.async.} =
            let stream = await mediaDevices().getUserMedia(JsObject{video: true})
            let elem = document.getElementById("video")
            elem.setStream(stream)

        scope.model.fetch_data = bindMethod proc (that: JsObject) {.async.} =
            let response = await fetch("https://google.nl")
            echo await response.text()

        scope.model.show_button = bindMethod proc(that: JsObject) =
            echo "clicked me! " & scope.model.selected.to(cstring)
            scope.model.show = true
            scope.digest()

        scope.model.del_button = bindMethod proc(that: JsObject, scolp: Tscope) {.async.} =
            let todo = scolp.model.todo.to(Todo)
            let ok = await indexedDB().delete("todos", todo.id)
            if ok:
                scope.model.todos = await indexedDB().getAll("todos")
                scope.digest()
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
                done: scope.model.done.to(bool),
                content: scope.model.content.to(cstring)
            )

            let ok = await indexedDB().put("todos", toJs todo)

            if ok:
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
