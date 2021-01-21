import ../src/tangu, json, dom

let viewTodosController = newController(
    "viewTodos",
    staticRead("view.html"),
    proc(scope: Tscope, lifecycle: Tlifecycle) =

    scope.model{"todos"} = scope.root().model{"todos"}

    case lifecycle:
        of Tlifecycle.Created:
            if scope.root().model{"todos"}.isNil():
                scope.root().model{"todos"} = %[]

            scope.model{"show"} = %false
            scope.model{"intro"} = %"click on the add button to navigate to the add controller"

            scope.methods = @[
                newMethod("show_button", proc (scope: Tscope) {.closure.} =
                echo "clicked me!"
                scope.model{"show"} = %true
            ),
                newMethod("del_button", proc (scope: Tscope) {.closure.} =
                for i, s in scope.root().model{"todos"}.elems:
                    if s{"id"}.to(int) == scope.model{"todo", "id"}.to(int):
                        scope.root().model{"todos"}.elems.delete(i)
                        break
            )]

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
            scope.methods = @[
                newMethod("done_button", proc (scope: Tscope) =

                let todo = newJObject()
                todo{"id"} = %scope.root().model{"todos"}.len
                todo{"done"} = scope.model{"done"}
                todo{"content"} = scope.model{"content"}

                scope.root().model{"todos"}.add(todo)

                window.location.hash = "#!/"
            )]

        of Tlifecycle.Resumed:
            echo "resumed"
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
        viewTodosController,
        addTodoController],
    @[
        newRoute("/", "viewTodos"),
        newRoute("/add", "addTodo")]
)
tng.bootstrap()

