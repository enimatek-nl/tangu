import jsffi, asyncjs

type
    FetchResponse = ref object of RootObj
        url: cstring
        ok: bool
        status: cint
        statusText: cstring
        headers: JsObject

    FetchOptions = ref object of RootObj
        `method`*: cstring
        mode*: cstring
        cache*: cstring
        credentials*: cstring
        headers*: JsObject
        redirect*: cstring
        referrerPolicy*: cstring
        body*: cstring

proc fetch*(url: cstring): Future[FetchResponse] {.importcpp: "fetch(#)".}
proc json*(self: FetchResponse): Future[JsObject] {.importcpp.}
proc text*(self: FetchResponse): Future[cstring] {.importcpp.}


# type Test = ref object
#     model*: JsObject
#     content*: string

# when isMainModule:
#     let test = Test(model: newJsObject())
#     test.content = "asdsadsasad"

#     test.model["call"] = bindMethod proc (that: JsObject, scope: Tscope) {.async.} =
#         let response = await fetch("https://google.com")
#         echo test.content

#     test.model.call(test)
