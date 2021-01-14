# Tangu

client side javascript web app framework in nim (js)

### About

It's like angular or veu.js but made in `nim` and uses `json` to pass data between javascript and the nim code.

### Changes

  - 0.1.0 Initial publish

### Getting Started

#### Intro
Check the `demo` folder for a simple demo.

Basically you create your html and make use of the `Tdirective`s that are available which are at the moment

#### Directives

  - `tng-router` this is the starting point of tangu
  - `tng-if` show or hide the node based on a boolean or int > 0
  - `tng-model` bind the input to the `JsonNode` in the code
  - `tng-bind` bind the `innerHTML` to the `JsonNode` in the code
  - `tng-click` bind the `onclick` to a `scope.methods` in the code
  - `tng-repeat` repeat the node for each `JArray` it binds to

#### An HTML example `test.html`

```html
<div>

    <i>input 'foo'</i>
    <input tng-model="foo" type="text">

    <i>span bind to 'foo'</i>
    <span tng-bind="foo"></span><br>

    <button tng-click="button">show YES!</button><br>

    <div tng-if="show">
        <h1>YES!</h1>
    </div>

    <div tng-repeat="item in list">
        <span tng-bind="item.msg"></span>
    </div>

</div>
```

#### The example tangu nim controller `test.nim`

```nim
import tangu, json

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
```

#### Conclusion

To boot this example you need an html file including your `nim js test.nim` file and put the `tng-router="test"` in this page somewhere.
This is basically it.

### Roadmap

- [X] Put current code on GitHub
- [ ] More essential `directives`
- [ ] `pushPage` and `popPage` to navigate through the stack of controllers
- [ ] add `nimble` tasks and / or cli to run a local server
- [ ] Integrate popular css framework