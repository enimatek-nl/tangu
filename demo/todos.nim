import ../src/tangu, json, dom

let loginController = newController(
    "login",
    staticRead("login.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =
    scope.methods.add newMethod("login_button", proc (scope: Tscope) =
        scope.root().model{"authenticated"} = %true
        window.location.hash = "#!/"
    )
)

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    if scope.root().model{"todos"}.isNil():
        scope.root().model{"todos"} = %[]
    scope.model{"show"} = %false

    if lifecycle == Tlifecycle.Created:

        scope.model{"todos"} = scope.root().model{"todos"} # connect the local 'todos' to the root-scope
        scope.model{"intro"} = %"click on the add button to navigate to the add controller"

        scope.methods.add newMethod("show_button", proc (scope: Tscope) {.closure.} =
            echo "clicked me!"
            window.indexedDB.open("bla.db", 1)
            scope.model{"show"} = %true
        )

        scope.methods.add newMethod("del_button", proc (scope: Tscope) {.closure.} =
            for i, s in scope.root().model{"todos"}.elems:
                if s{"id"}.to(int) == scope.model{"todo", "id"}.to(int):
                    scope.root().model{"todos"}.elems.delete(i)
                    break
        )
)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    # reset the form input
    scope.model{"done"} = %false
    scope.model{"content"} = %""

    if lifecycle == Tlifecycle.Created:
        scope.methods.add newMethod("done_button", proc (scope: Tscope) =

            let todo = newJObject()
            todo{"id"} = %scope.root().model{"todos"}.len
            todo{"done"} = scope.model{"done"}
            todo{"content"} = scope.model{"content"}

            scope.root().model{"todos"}.add(todo)

            window.location.hash = "#!/"
        )
)

let auth = newGuard(proc (self: Tguard, cname: string, scope: Tscope): bool =
    # use 'authenticated' in the root scope to guard the controllers
    if scope.isNil or scope.root().model{"authenticated"}.isNil or not scope.root().model{"authenticated"}.to(bool):
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

