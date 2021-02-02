import dom, jsffi, asyncjs

type
    MediaDevices {.importc.} = ref object of EventTarget

    MediaStream {.importc.} = ref object of RootObj

    ServiceWorkerContainer {.importc.} = ref object of RootObj
    ServiceWorkerRegistration {.importc.} = ref object of RootObj

    NavigatorMD* = ref object of Navigator
        mediaDevices*: MediaDevices
        serviceWorker*: ServiceWorkerContainer

proc register*(self: ServiceWorkerContainer, scriptURL: cstring): Future[ServiceWorkerRegistration] {.importcpp.}

proc getUserMedia*(self: MediaDevices, constraints: JsObject): Future[MediaStream] {.importcpp.}
proc setStream*(self: Element, stream: MediaStream) {.importcpp: "#.srcObject = #".}


var window* {.importc, nodecl.}: WindowDB
var navigator* {.importc, nodecl.}: NavigatorMD

proc main(): Future[void] {.async.} =
    let stream = await navigator.mediaDevices.getUserMedia(JsObject{video: true})
    let elem = document.getElementById("video")
    elem.setStream(stream)

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
