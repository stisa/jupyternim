# Provide a way to send display_data messages
import json, base64, streams, nimPNG
export json.`$`

type DisplayKind* = enum
  dkPng, dkPlot

const startmarker = "#<jndd>#"
const endmarker = "#<outjndd>#"

proc showImpl*[T](kind:DisplayKind, what:PNG[T], w:int=480,h:int=320):JsonNode =
  var ss = newStringStream("")
  writeChunks(what, ss)
  ss.setPosition(0)

  result = %*{
    "data": {"image/png": encode(ss.readAll) }, # TODO: handle other mimetypes
    "metadata": %*{"image/png": {"width": w, "height":h}},
    "transient": %*{}
  }

proc showImpl*(kind:DisplayKind, what:string, w:int=480,h:int=320): JsonNode =
  result = %*{
      "data": {"image/png": what}, # TODO: handle other mimetypes
      "metadata": %*{"image/png": {"width": w, "height": h}}, #FIXME: sizes from 0000x0000
      "transient": %*{}
    }

template show*(kind:DisplayKind, what:untyped, w:int=480,h:int=320) =
  #TODO: find a way to print only if the current cellId is the executing one
  var content = showImpl(kind, what, w, h)
  stdout.write(startmarker, $content, endmarker)
  stdout.flushFile()

