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
        )
    ]
)

let tng = newTangu(@[tngIf(), tngRepeat(), tngBind(), tngModel(), tngClick(), tngRouter()], @[testController])
tng.bootstrap()

