import jsffi, asyncjs, dom

type
    MediaDevices {.importc.} = ref object of EventTarget

    MediaStream {.importc.} = ref object of RootObj

    NavigatorMD* = ref object of Navigator
        mediaDevices*: MediaDevices

## Add a camera video stream by adding a <video> element and as an example do:
## `let stream = await mediaDevices.getUserMedia(JsObject{video: true})`
## `let elem = document.getElementById("video")`
## `elem.setStream(stream)`
proc mediaDevices*(): MediaDevices {.importcpp: "function() { return navigator.mediaDevices; }()".}

proc getUserMedia*(self: MediaDevices, constraints: JsObject): Future[MediaStream] {.importcpp.}
proc setStream*(self: Element, stream: MediaStream) {.importcpp: "#.srcObject = #".}
