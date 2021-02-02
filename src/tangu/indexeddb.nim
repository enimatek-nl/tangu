import jsffi, asyncjs, dom

type
    IndexedDB {.importc.} = ref object of RootObj

    IDBOptions = ref object of RootObj
        autoIncrement: cint
        keyPath: cstring

    IDBTransaction {.importc.} = ref object of RootObj
        onerror*: proc (event: Event) {.closure.}
        oncomplete*: proc (event: Event) {.closure.}

    IDBDatabase {.importc.} = ref object of RootObj
        name: cstring
        version: cint
        objectStoreNames: seq[cstring]

    IDBObjectStore {.importc.} = ref object of RootObj
        indexNames: seq[cstring]
        name: cstring
        transaction: IDBTransaction
        autoIncrement: cint

    IDBOpenDBRequest {.importc.} = ref object of RootObj
        onerror*: proc (event: Event) {.closure.}
        onsuccess*: proc (event: Event) {.closure.}
        onupgradeneeded*: proc (event: Event) {.closure.}
        result: IDBDatabase

proc indexedDB*(): IndexedDB {.importcpp: "function() { return window.indexedDB; }()".}

proc open*(self: IndexedDB, dbName: cstring): IDBOpenDBRequest {.importcpp.}
proc open*(self: IndexedDB, dbName: cstring, s: cint): IDBOpenDBRequest {.importcpp.}

proc transaction*(self: IDBDatabase, names: cstring): IDBTransaction {.importcpp.}
proc transaction*(self: IDBDatabase, names: seq[cstring]): IDBTransaction {.importcpp.}
proc transaction*(self: IDBDatabase, names: cstring, mode: cstring): IDBTransaction {.importcpp.}
proc transaction*(self: IDBDatabase, names: seq[cstring], mode: cstring): IDBTransaction {.importcpp.}

proc deleteObjectStore*(self: IDBDatabase, name: cstring) {.importcpp.}
proc createObjectStore*(self: IDBDatabase, name: cstring, options: IDBOptions): IDBObjectStore {.importcpp.}
proc close*(self: IDBDatabase) {.importcpp.}

proc objectStore*(self: IDBTransaction, name: cstring): IDBObjectStore {.importcpp.}

proc add*(self: IDBObjectStore, value: JsObject) {.importcpp.}
proc add*(self: IDBObjectStore, value: JsObject, key: JsObject) {.importcpp.}
