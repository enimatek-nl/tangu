import ../src/tangu, json, dom

const static_test = staticRead("view.html")
let viewTodosController = Tcontroller(name: "viewTodos", view: static_test, work: proc(scope: Tscope, lifecycle: Tlifecycle) =

    scope.model{"todos"} = scope.root().model{"todos"}

    case lifecycle:
        of Tlifecycle.Created:
            if scope.root().model{"todos"}.isNil(): scope.root().model{"todos"} = %* []

            scope.model = %* {
                "show": false,
                "intro": "click on the add button to navigate to the add controller",
                "todos": %*[]
            }

            scope.methods = @[
                (n: "show_button", f: proc (scope: Tscope) {.closure.} =
                    echo "clicked me!"
                    scope.model{"show"} = %* true
                ),

                (n: "del_button", f: proc (scope: Tscope) {.closure.} =
                    for i, s in scope.root().model{"todos"}.elems:
                        if s{"id"}.to(int) == scope.model{"todo", "id"}.to(int):
                            scope.root().model{"todos"}.elems.delete(i)
                            break
                )
            ]
        of Tlifecycle.Resumed:
            echo "resumed"
        of Tlifecycle.Destroyed:
            echo "destroyed"
)

const static_test2 = staticRead("add.html")
let addTodoController = Tcontroller(name: "addTodo", view: static_test2, work: proc(scope: Tscope, lifecycle: Tlifecycle) =
    case lifecycle:
        of Tlifecycle.Created:
            scope.model = %* {
                "done": false,
                "content": ""
            }

            scope.root().model{"title"} = %* "Add Todo"

            scope.methods = @[
                (n: "done_button", f: proc (scope: Tscope) {.closure.} =

                    scope.root().model{"todos"}.add( %* {
                        "id": scope.root().model{"todos"}.len,
                        "done": scope.model{"done"},
                        "content": scope.model{"content"}}
                    )

                    window.location.hash = "#!/"
                )
            ]

        of Tlifecycle.Resumed:
            scope.model = %* {
                "done": false,
                "content": ""
            }

        of Tlifecycle.Destroyed:
            echo "destroyed"
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
        (path: "/", controller: "viewTodos"),
        (path: "/add", controller: "addTodo")]
)
tng.bootstrap()

