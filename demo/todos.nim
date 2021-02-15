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
    scope.model{"todos"} = scope.root().model{"todos"}

    case lifecycle:
        of Tlifecycle.Created:

            scope.model{"show"} = %false
            scope.model{"intro"} = %"click on the add button to navigate to the add controller"

            scope.methods.add newMethod("show_button", proc (scope: Tscope) {.closure.} =
                echo "clicked me!"
                scope.model{"show"} = %true
            )

            scope.methods.add newMethod("del_button", proc (scope: Tscope) {.closure.} =
                for i, s in scope.root().model{"todos"}.elems:
                    if s{"id"}.to(int) == scope.model{"todo", "id"}.to(int):
                        scope.root().model{"todos"}.elems.delete(i)
                        break
            )

        of Tlifecycle.Resumed:
            echo "resumed"
)

let addTodoController = newController(
    "addTodo",
    staticRead("add.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    scope.model{"done"} = %false
    scope.model{"content"} = %""

    case lifecycle:
        of Tlifecycle.Created:
            scope.methods.add newMethod("done_button", proc (scope: Tscope) =

                let todo = newJObject()
                todo{"id"} = %scope.root().model{"todos"}.len
                todo{"done"} = scope.model{"done"}
                todo{"content"} = scope.model{"content"}

                scope.root().model{"todos"}.add(todo)

                window.location.hash = "#!/"
            )

        of Tlifecycle.Resumed:
            echo "resumed"
)

let auth = newGuard(proc (self: Tguard, cname: string, scope: Tscope): bool =
    self.hash = "#!/login"
    if scope.isNil or scope.root().model{"authenticated"}.isNil or not scope.root().model{"authenticated"}.to(bool):
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

