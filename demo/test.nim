import ../src/tangu, json

const static_test = staticRead("test.html")
let testController = Tcontroller(name: "test", view: static_test, construct: proc(scope: Tscope) =
    scope.model = %* {
        "foo": "empty",
        "show": false,
        "list": [
            {"msg": "this is a"},
            {"msg": "this is b"},
            {"msg": "this is c"}
        ],
        "todos": [],
        "todo": {
            "msg": ""
        }
    }
    scope.methods = @[
        (n: "button", f: proc (scope: Tscope) {.closure.} =
            echo "clicked me!"
            scope.model{"show"}.bval = true
        ),
        (n: "add", f: proc (scope: Tscope) {.closure.} =
            scope.model{"todos"}.elems.add(%* {"msg": scope.model{"todo", "msg"}.str})
            scope.model{"todo", "msg"}.str = ""
        ),
        (n: "delete", f: proc (scope: Tscope) {.closure.} =
            echo "within scope: " & scope.model{"todo", "msg"}.str
        )
    ]
)

const static_test2 = staticRead("test2.html")
let test2Controller = Tcontroller(name: "test2", view: static_test2, construct: proc(scope: Tscope) =
    scope.model = %* {
        "title": "TEST"
    }
)

let tng = newTangu(
    @[
        tngIf(),
        tngRepeat(),
        tngBind(),
        tngModel(),
        tngClick(),
        tngRouter()],
    @[
        testController,
        test2Controller],
    @[
        (path: "/", controller: "test"),
        (path: "/hello", controller: "test2")]
)
tng.bootstrap()

