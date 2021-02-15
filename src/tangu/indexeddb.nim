import jsffi, asyncjs, dom

type
    IndexedDB {.importc.} = ref object of RootObj
    
    #IDBTransactionMode = enum
    #    readOnly = "readonly", readWrite = "readwrite", versionChange = "versionchange"

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

    IDBRequest {.importc.} = ref object of RootObj 
        onerror*: proc (event: Event) {.closure.}
        onsuccess*: proc (event: Event) {.closure.}
        result: JsObject

    IDBOpenDBRequest {.importc.} = ref object of RootObj
        onerror*: proc (event: Event) {.closure.}
        onsuccess*: proc (event: Event) {.closure.}
        onupgradeneeded*: proc (event: Event) {.closure.}
        result: IDBDatabase

proc indexedDB*(): IndexedDB {.importcpp: "function() { return window.indexedDB; }()".}

proc open(self: IndexedDB, dbName: cstring): IDBOpenDBRequest {.importcpp.}
proc open(self: IndexedDB, dbName: cstring, s: cint): IDBOpenDBRequest {.importcpp.}

proc transaction(self: IDBDatabase, names: cstring): IDBTransaction {.importcpp.}
proc transaction(self: IDBDatabase, names: seq[cstring]): IDBTransaction {.importcpp.}
proc transaction(self: IDBDatabase, names: cstring, mode: cstring): IDBTransaction {.importcpp.}
proc transaction(self: IDBDatabase, names: seq[cstring], mode: cstring): IDBTransaction {.importcpp.}

proc deleteObjectStore(self: IDBDatabase, name: cstring) {.importcpp.}
proc createObjectStore(self: IDBDatabase, name: cstring, options: IDBOptions): IDBObjectStore {.importcpp.}
proc close(self: IDBDatabase) {.importcpp.}

proc objectStore(self: IDBTransaction, name: cstring): IDBObjectStore {.importcpp.}

proc add(self: IDBObjectStore, value: JsObject) {.importcpp.}
proc add(self: IDBObjectStore, value: JsObject, key: JsObject) {.importcpp.}
proc get(self: IDBObjectStore, id: cint): JsObject {.importcpp.}
proc put(self: IDBObjectStore, value: JsObject): IDBRequest {.importcpp.}

proc loadFromIndexedDB*(storeName: cstring, id: cint): Future[JsObject] =
    var promise = newPromise() do (resolve: proc(response: JsObject)):
        let request = indexedDB().open(storeName)
        request.onerror = proc (event: Event) =
            echo "error"
        request.onupgradeneeded = proc (event: Event) =
            echo "upgrade"
        request.onsuccess = proc (event: Event) =
            let database = request.result
            let transaction = database.transaction(storeName, "readonly")
            let obj_store = transaction.objectStore(storeName)
            let obj_req = obj_store.get(id)
            obj_req.onerror = proc (event: Event) =
                echo "error"
            obj_req.onsuccess = proc (event: Event) =
                echo "success"
                resolve(obj_req.result)
    return promise

proc saveToIndexedDB*(storeName: cstring, obj: JsObject): Future[bool] =
    var promise = newPromise() do (resolve: proc(response: bool)):
        let request = indexedDB().open(storeName)
        request.onerror = proc (event: Event) =
            echo "error"
        request.onupgradeneeded = proc (event: Event) =
            let database = request.result
            discard database.createObjectStore(storeName, IDBOptions(keyPath: "id"))
            echo "upgrade"
        request.onsuccess = proc (event: Event) =
            let database = request.result
            let transaction = database.transaction(storeName, "readwrite")
            let obj_store = transaction.objectStore(storeName)
            let obj_req = obj_store.put(obj)
            obj_req.onerror = proc (event: Event) =
                echo "error"
            obj_req.onsuccess = proc (event: Event) =
                echo "success"
                resolve(true)
    return promise
