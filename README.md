# Tangu

client side single page javascript web app framework (SPA) in nim (js)

### About

It's like angular, mithril.js or vuejs but made in `nim` and uses `json` to pass data between javascript and the nim code.

### Changes

  - *****0.2.0** Big improvement to `tng-repeat` also introduces `#!` navigation between controllers and `animates` the transition. `tng-onchange` is added and `scopes` now have a common `root` and methodcalls are passed down their `children`
  - **0.1.0** Initial publish

### About

Tengu is a SPA (single page app framework) the uses the MVC (model view controller) principle. You can make a template in normal `html` and use `Tdirectives` in the html code.

These directives share a `model` that can be used in your code in a `Tcontroller` that you program in normal `nim`

#### Directives (used in HTML templates)

  - `tng-router` this is the starting point of tangu 
  - `tng-if` show or hide the node based on a boolean or int > 0
  - `tng-model` bind the input to the `JsonNode` in the code
  - `tng-bind` bind the `innerHTML` to the `JsonNode` in the code
  - `tng-change` bind `onchange` based on the `type` to what changed (eg checkbox `bool` on `checked`)
  - `tng-click` bind the `onclick` to a `scope.methods` in the code
  - `tng-repeat` repeat `itemName in JArrayName` the node for each `JArray` it binds to and maps the object `itemName`

#### The scope

The `root` scope is created at `index` level and exists before the `router`. Each `Tcontroller` is a child of the root-scope.

This way you can for instance create a top menu that is accessible by all controllers.

Another usecase is passing around data between controllers.

#### Hash Bang (#!)

The Single Page Application (SPA) uses `#!` and the end of the window.location for the navigation.

Changing the `#!` wil automatically trigger the controller that is mapped during the `newTangu(routes:@[])` to activate.

#### Animations

Tangu uses simple animation (css `@keyframe`) to switch between `Tcontrollers`. This is still a ~wip~ but a more extended api will be provided.

This will make the integration of css-frameworks more seamless since you do not need to embed the navigation system they often offer to get the benefit of the animations.

### Getting Started

#### Intro
Check the `demo` folder for a simple demo demo todos application touching almost all topics that are currently possible.

Basically you create your html and make use of the `Tdirective`s that are available which are at the moment

#### An HTML example `test.html`

```html
<div>

    <input tng-model="foo" type="text">
    <span tng-bind="foo"></span><br>

    <button tng-click="add_button">add</button><br>

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
        "foo": "",
        "list": [
            {"msg": "this is a"},
            {"msg": "this is b"},
            {"msg": "this is c"}
        ]
    }

    scope.methods = @[
        (n: "add_button", f: proc (scope: Tscope) {.closure.} =
            scope.model{"list"}.add(%*{
                "msg": scope.model{"foo"}.str
            })
            scope.model{"foo"}.str = ""
        )
    ]
)

let tng = newTangu(@[ tngRepeat(), tngBind(), tngModel(), tngClick(), tngRouter()], @[testController], @[(path: "/", controller: "test")])
tng.bootstrap()
```

#### Conclusion

To boot this example you need an html file including your `nim js test.nim` file and put the `tng-router="/"` in this page somewhere.
This is basically it.

### Roadmap

- [ ] introduce a lifecyle system for controllers
- [ ] create a central `root()` scope configuration
- [ ] research the `service` or `singlton` paradigm 
- [ ] add `nimble` tasks and / or cli to run a local server
