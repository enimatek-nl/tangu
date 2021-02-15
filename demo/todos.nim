import ../src/tangu, jsffi, dom

let loginController = newController(
    "login",
    staticRead("login.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =
    scope.methods.add newMethod("login_button", proc (scope: Tscope) =
        scope.root().model["authenticated"] = toJs(true)
        window.location.hash = "#!/"
    )
)

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    if scope.root().model["todos"].isNil:
        scope.root().model["todos"] = toJs([])
    scope.model["show"] = toJs(false)

    if lifecycle == Tlifecycle.Created:

        scope.model["todos"] = scope.root().model["todos"] # connect the local 'todos' to the root-scope
        scope.model["intro"] = toJs "click on the add button to navigate to the add controller"

        scope.methods.add newMethod("show_button", proc (scope: Tscope) {.closure.} =
            echo "clicked me!"
            scope.model["show"] = toJs true
        )

        scope.methods.add newMethod("del_button", proc (scope: Tscope) {.closure.} =
            var objs = scope.root().model["todos"].to(seq[JsObject])
            var o = -1
            for i, s in objs:
                if s["id"].to(int) == scope.model["todo"]["id"].to(int):
                    o = i
            if o != -1:
                objs.delete(o)
                discard scope.root().model.set("todos", toJs objs)
        )
)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    # reset the form input
    scope.model["done"] = toJs false
    scope.model["content"] = toJs ""

    if lifecycle == Tlifecycle.Created:
        scope.methods.add newMethod("done_button", proc (scope: Tscope) =

            let todo = JsObject{
                id: toJs scope.root().model["todos"].to(seq[JsObject]).len,
                done: scope.model["done"],
                content: scope.model["content"]
            }

            var obj = scope.root().model["todos"].to(seq[JsObject])
            obj.add(todo)
            discard scope.root().model.set("todos", toJs obj)

            window.location.hash = "#!/"
        )
)

let auth = newGuard(proc (self: Tguard, cname: string, scope: Tscope): bool =
    # use 'authenticated' in the root scope to guard the controllers
    if scope.isNil or scope.root().model["authenticated"].isNil or not scope.root().model["authenticated"].to(bool):
        self.hash = "#!/login"
        return false
    else:
        return true
)

let tng = newTangu(
    @[
        tngIf(),
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

