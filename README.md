# Tangu

client side single page javascript web app framework (SPA) in nim (js)

### About

It's like angular, mithril.js or vuejs but made in `nim` and uses `json` to pass data between javascript and the nim code.

### Changes

#### 0.3.0
Introducing `new..` methods for routing, methods etc. improved the scope handling added lifecycles, route guards, updated the demo-code and created a wiki

#### 0.2.0
Big improvement to `tng-repeat` also introduces `#!` navigation between controllers and `animates` the transition. `tng-onchange` is added, scopes now have a common root and methodcalls are passed down their children

#### 0.1.0
Initial publish

### Getting Started

Check out the [minimal code example](https://github.com/enimatek-nl/tangu/wiki) in wiki.

### Roadmap

- [X] introduce a lifecyle system for controllers
- [X] create a central `root()` scope configuration
- [X] authentication `guard` paradigm 
- [ ] improve and add directives
- [ ] research the `service` or `singlton` paradigm 
- [ ] add `nimble` tasks and / or cli to run a local server
