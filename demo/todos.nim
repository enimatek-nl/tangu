import asyncjs, jsffi, dom
import ../src/tangu

type
    Todo = ref object
        id: int
        content: string
        done: bool

    Extra = ref object
        text: cstring
        selected: bool

let loginController = newController(
    "login",
    staticRead("login.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    scope.model.login_button = bindMethod proc (that: JsObject) {.async.} =
        scope.root().model.authenticated = true
        window.location.hash = "#!/"

)

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    if scope.root().model.todos.isNil:
        scope.root().model.todos = []
    scope.model.show = false

    if lifecycle == Tlifecycle.Created:

        scope.model.todos = scope.root().model.todos # connect the local 'todos' to the root-scope
        scope.model.intro = "click on the add button to navigate to the add controller"
        scope.model.selected = "abc"

        scope.model.extras = [
            Extra(text: "nested", selected: false),
            Extra(text: "repeat", selected: false),
            Extra(text: "tag", selected: true)
        ]

        scope.model.fetch_data = bindMethod proc (that: JsObject, scope: Tscope, node: Node) {.async.} =
            let response = await fetch("https://google.nl")
            echo await response.text()

        scope.model.show_button = bindMethod proc(that: JsObject, scope: Tscope, node: Node) =
            echo "clicked me! " & scope.model.selected.to(cstring)
            scope.model.show = true

        scope.model.del_button = bindMethod proc(that: JsObject, scope: Tscope, node: Node) =
            for i, s in scope.root().model.todos.to(seq[Todo]):
                if s.id == scope.model.todo.to(Todo).id:
                    scope.root().model.delete("todos", i)
                    break
)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    # reset the form input
    scope.model.done = false
    scope.model.content = ""

    if lifecycle == Tlifecycle.Created:
        scope.model.done_button = bindMethod proc(that: JsObject, scope: Tscope, node: Node) =
            let todo = Todo(
                id: scope.root().model.todos.to(seq[JsObject]).len,
                done: scope.model.done.to(bool),
                content: scope.model.content.to(string)
            )

            scope.root().model.add("todos", todo)

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
