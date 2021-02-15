import dom, jsffi, asyncjs



var window* {.importc, nodecl.}: WindowDB
var navigator* {.importc, nodecl.}: NavigatorMD

    ServiceWorkerContainer {.importc.} = ref object of RootObj
    ServiceWorkerRegistration {.importc.} = ref object of RootObj

        serviceWorker*: ServiceWorkerContainer

proc main(): Future[void] {.async.} =

    let request = window.indexedDB.open("test.db")

    request.onupgradeneeded = proc (event: Event) =
        echo "upgrade needed"
        let db = request.result
        let objectStore = db.createObjectStore("my-store-name", IDBOptions(autoIncrement: 1))

    request.onsuccess = proc (event: Event) =
        echo "success"
        let db = request.result
        let transaction = db.transaction("my-store-name", "readwrite")
        let objectStore = transaction.objectStore("my-store-name")
        objectStore.add(JsObject{"id": 1, "name": "abc"})

    request.onerror = proc (event: Event) =
        echo "error"


when isMainModule:
    let a = main()
