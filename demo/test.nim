import dom, jsffi
from strutils import split

proc jsStringify*(x: JsObject): cstring {.importcpp: "JSON.stringify(#)".}
proc jsIsArray*(x: JsObject): bool {.importcpp: "Array.isArray(#)".}

proc set(self: JsObject, path: string, val: JsObject): bool =
    ## Look for the `path` in the `JsObject` and overwrite the value
    var s = self
    let r = path.split(".")
    for i, v in r:
        if s.hasOwnProperty(v):
            if i == r.len - 1:
                s[v] = val
            else:
                s = s[v]
        else:
            return false
    return true

let obj = JsObject{"a": JsObject{"b": JsObject{"c": toJs([JsObject{"a": "asd"}, toJs"asd", toJs"Asd"])}}}

#discard obj.set("a.b.c", toJs"bla")

echo jsIsArray(obj["a"]["b"]["c"])

for z in obj["a"]["b"]["c"].to(seq[cstring]):
    echo z.typeOf

echo jsStringify(obj)

