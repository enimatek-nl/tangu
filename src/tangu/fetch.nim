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

## Just use `fetch("http:..")` to receive a `FetchResponse` or fill the `FetchOptions` for more advanced fetches
proc fetch*(url: cstring): Future[FetchResponse] {.importcpp: "fetch(#)".}
proc fetch*(url: cstring, options: FetchOptions): Future[FetchResponse] {.importcpp: "fetch(#)".}

proc json*(self: FetchResponse): Future[JsObject] {.importcpp.}
proc text*(self: FetchResponse): Future[cstring] {.importcpp.}
