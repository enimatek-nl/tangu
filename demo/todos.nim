import ../src/tangu, json, dom

const static_test = staticRead("view.html")
let viewTodosController = Tcontroller(name: "viewTodos", view: static_test, construct: proc(scope: Tscope) =

    scope.root().model{"title"} = %* "Overview Todos"

    scope.model = %* {
        "show": false,
        "intro": "click on the add button to navigate to the add controller",
        "todos": scope.root().model{"todos"}
    }

    scope.methods = @[
        (n: "show_button", f: proc (scope: Tscope) {.closure.} =
            echo "clicked me!"
            scope.model{"show"} = %* true
        ),
        (n: "del_button", f: proc (scope: Tscope) {.closure.} =
            echo $scope.model{"todo", "id"}
        )
    ]
)

const static_test2 = staticRead("add.html")
let addTodoController = Tcontroller(name: "addTodo", view: static_test2, construct: proc(scope: Tscope) =

    scope.root().model{"title"} = %* "Add Todo"

    scope.model = %* {
        "done": false,
        "content": "my todo..."
    }

    scope.methods = @[
        (n: "done_button", f: proc (scope: Tscope) {.closure.} =
            echo "done!"
            if scope.root().model{"todos"}.isNil(): scope.root().model{"todos"} = %* []
            scope.root().model{"todos"}.add(%* {
                "id": scope.root().model{"todos"}.len,
                "done": scope.model{"done"},
                "content": scope.model{"content"}}
            )
            window.location.hash = "#!/"
        )
    ]
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

