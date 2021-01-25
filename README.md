# Tangu

A client side single page javascript web app framework (SPA) in nim (js)

### About

It's like angularjs / mithril.js / vuejs but made in `nim js` and uses `jsffi` to pass data between javascript and the nim code.
Check out the [minimal code example](https://github.com/enimatek-nl/tangu/wiki) in wiki.

### Changes

####

#### 0.4.0
Removed `json` dependency and now tangu uses `jsffi`s `JsObject` to pass data from nim to the model. Wiki and the demo has been updated accordingly.

#### 0.3.0
Introducing `new..` methods for routing, methods etc. improved the scope handling added lifecycles, route guards, updated the demo-code and created a wiki.

#### 0.2.0
Big improvement to `tng-repeat` also introduces `#!` navigation between controllers and `animates` the transition. `tng-onchange` is added, scopes now have a common root and methodcalls are passed down their children.

#### 0.1.0
Initial publish.

### Documentation
Check out the [wiki](https://github.com/enimatek-nl/tangu/wiki) to get information about:

  - [routing](https://github.com/enimatek-nl/tangu/wiki/Routing)
  - [directives](https://github.com/enimatek-nl/tangu/wiki/Directives)

### Roadmap

- [X] introduce a lifecyle system for controllers
- [X] create a central `root()` scope configuration
- [X] authentication `guard` paradigm 
- [ ] improve and add directives
- [ ] research the `service` or `singlton` paradigm 
- [ ] add `nimble` tasks and / or cli to run a local server
