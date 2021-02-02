# <img src="https://user-images.githubusercontent.com/77200435/105724995-baaa8500-5f28-11eb-94ff-70ffa5e8511a.png" height="48px"/> Tangu

A client side single page javascript web app framework (SPA) in nim (js)

### About

It's like angularjs / mithril.js / vuejs but made in `nim js` and uses `jsffi` to pass data between javascript and the nim code.
Check out the [minimal code example](https://github.com/enimatek-nl/tangu/wiki) in wiki.

### Changes
Check the [Releases](https://github.com/enimatek-nl/tangu/releases) for details about the changes between each version.

### Documentation
Check out the [wiki](https://github.com/enimatek-nl/tangu/wiki) to get information about:

  - [standard directives](https://github.com/enimatek-nl/tangu/wiki/Standard-Directives)
  - [routing and guards](https://github.com/enimatek-nl/tangu/wiki/Routing-and-Guards)
  - [scope and lifecycle](https://github.com/enimatek-nl/tangu/wiki/Scope-and-Lifecycle)

#### Roadmap
Planned features and research subjects to complete the framework as a production usable thing.

### Features
- [X] introduce a lifecyle system for controllers
- [X] create a central `root()` scope configuration
- [X] authentication `guard` paradigm 
- [X] rebuild core based on `jsffi`
- [X] add `fetch` with async/await capabilities
- [X] implement a default indexedDB service for persisting `JsObject`
- [ ] implement a base service for PWA management (?)
- [ ] improve and add directives
- [X] add `nimble` tasks 
- [ ] cli to run a local server or setup project
- [ ] research cordova compatibility

### Issues
- [X] Fix how `Node` directive replaces or updates (grabs the incorrect ones now when doing eg. two repeats in one parent node)
- [ ] Introduce a more central way of configuring the 'root' scope during setup (?)
