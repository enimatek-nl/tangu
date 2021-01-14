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
        ]
    }
    scope.methods = @[
        (n: "button", f: proc (scope: Tscope) {.closure.} =
            echo "clicked me!"
            scope.model{"show"}.bval = true
        )
    ]
)

let tng = newTangu(@[tngIf(), tngRepeat(), tngBind(), tngModel(), tngClick(), tngRouter()], @[testController])
tng.bootstrap()

