# Provide a way to send display_data messages
import json, base64, streams, nimPNG
export json.`$`

type DisplayKind* = enum
  dkPng, dkPlot, dkPngFile

const startmarker = "#<jndd>#"
const endmarker = "#<outjndd>#"

proc showPngFile*(what:string, w:int=480,h:int=320):JsonNode =
  result = %*{
    "data": {"image/png": encode(readFile(what)) }, # TODO: handle other mimetypes
    "metadata": %*{"image/png": {"width": w, "height":h}},
    "transient": %*{}
  }

proc showInMemPng*(what:PNG[string], w:int=480,h:int=320):JsonNode =
  var ss = newStringStream("")
  writeChunks(what, ss)
  ss.setPosition(0)

  result = %*{
    "data": {"image/png": encode(ss.readAll) }, # TODO: handle other mimetypes
    "metadata": %*{"image/png": {"width": w, "height":h}},
    "transient": %*{}
  }

proc showBase64StringPng*(what:string, w:int=480,h:int=320): JsonNode =
  result = %*{
      "data": {"image/png": what}, # TODO: handle other mimetypes
      "metadata": %*{"image/png": {"width": w, "height": h}}, #FIXME: sizes from 0000x0000
      "transient": %*{}
    }

template show*(kind:DisplayKind, size: array[2, int] = [480,320], what:untyped) =
  #TODO: find a way to print only if the current cellId is the executing one
  var content : JsonNode
  when kind == dkPng:
    content = showInMemPng(what, size[0], size[1])
  when kind == dkPngFile:
    content = showPngFile(what, size[0], size[1])
  when kind == dkPlot:
    content = showBase64StringPng(what, size[0], size[1])
  
  stdout.write(startmarker, $content, endmarker)
  stdout.flushFile()

