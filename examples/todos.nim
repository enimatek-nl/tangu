import asyncjs, sequtils, jsffi, dom
import tangu, tangu/mediadevices, tangu/indexeddb

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

        if lifecycle == Tlifecycle.Created:
            scope.model.login_button = bindMethod proc (that: JsObject) {.async.} =
                scope.root().model.authenticated = true
                window.location.hash = "#!/"
)

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

        scope.model.todos = await indexedDB().getAll("todos")

        if lifecycle == Tlifecycle.Created:

            proc doFilter(scope: Tscope) {.async.} =
                let todos = (await indexedDB().getAll("todos")).to(seq[Todo])
                
                if scope.model.filter.to(string) == "undone":
                    scope.model.todos = todos.filterIt(it.done == false)
                elif scope.model.filter.to(string) == "done":
                    scope.model.todos = todos.filterIt(it.done == true)
                else:
                    scope.model.todos = todos

                scope.digest()

            scope.model.filter = "all"
            scope.model.intro = "click on the add button to navigate to the add controller"
            scope.model.selected = "abc"

            scope.model.extras = [
                Extra(text: "undone", selected: false),
                Extra(text: "done", selected: false),
                Extra(text: "all", selected: true)
            ]

            scope.model.new_filter = bindMethod proc (that: JsObject, scolp: Tscope, node: Node) {.async.} =
                scope.model.filter = $node.value
                await doFilter(scope)

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
                await doFilter(scope)
            
        if lifecycle == Tlifecycle.Resumed:
            scope.model.filter = "all"
            scope.model.todos = await indexedDB().getAll("todos")

)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

        if lifecycle == Tlifecycle.Created:
            scope.model.content = ""

            scope.model.camera_button = bindMethod proc (that: JsObject) {.async.} =
                window.location.hash = "#!/camera"

            scope.model.done_button = bindMethod proc(that: JsObject, scope: Tscope, node: Node) {.async.} =
                let todo = Todo(
                    id: genId(),
                    done: false,
                    content: scope.model.content.to(cstring)
                )

                if await indexedDB().put("todos", toJs todo):
                    scope.model.content = ""
                    window.location.hash = "#!/"
)


let cameraTodoController = newController(
    "cameraTodo",
    staticRead("camera.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) {.async.} =

        if lifecycle == Tlifecycle.Created:

            scope.model.add_button = bindMethod proc (that: JsObject) {.async.} =
                echo "add!"

            scope.model.start_button = bindMethod proc (that: JsObject) {.async.} =
                echo "picture"

        if lifecycle == Tlifecycle.Initialized:
            let stream = await mediaDevices().getUserMedia(JsObject{video: true})
            let elem = document.getElementById("video")
            elem.setStream(stream)
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
        addTodoController,
        cameraTodoController],
    @[
        newRoute("/login", "login"),
        newRoute("/", "viewTodos", auth),
        newRoute("/add", "addTodo", auth),
        newRoute("/camera", "cameraTodo", auth)]
)
tng.bootstrap()
