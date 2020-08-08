# Provide a way to send display_data messages
import json, base64, streams, mimetypes, os, strutils
export json.`$`
import nimPNG
type DisplayKind* = enum
  dkPng, dkPlot, dkFile, dkTextFile, dkImageFile, dkHtml

const startmarker = "#<jndd>#"
const endmarker = "#<outjndd>#"
let mimeDB = newMimetypes()

proc showBinaryFile*(what:string):JsonNode =
  let mime = mimeDB.getMimetype(what.splitFile().ext)
  result = %*{
    "data": {mime: encode(readFile(what)) }, # TODO: handle other mimetypes
    "metadata": %* {},
    "transient": %* {}
  }

proc showImgFile*(what:string, w:int=480,h:int=320):JsonNode =
  let mime = mimeDB.getMimetype(what.splitFile().ext)
  result = %*{
    "data": {mime: encode(readFile(what)) }, # TODO: handle other mimetypes
    "metadata": %*{mime: {"width": w, "height":h}},
    "transient": %* {}
  }

proc showTextFile*(what:string):JsonNode =
  let mime = mimeDB.getMimetype(what.splitFile().ext)
  #echo mime
  result = %*{
    "data": {mime: readFile(what),
             "text/plain": readFile(what)}, # TODO: handle other mimetypes
    "metadata": %* {},
    "transient": %* {}
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

proc showHtml*(what:string): JsonNode =
  result = %*{
      "data": {"text/html": what}, # TODO: handle other mimetypes
      "metadata" : %*{},
      "transient": %*{}
  }

template show*(kind:DisplayKind, size: array[2, int], what:untyped) =
  #TODO: find a way to print only if the current cellId is the executing one
  var content : JsonNode
  when kind == dkPng:
    content = showInMemPng(what, size[0], size[1])
  elif kind == dkImageFile:
    content = showImgFile(what, size[0], size[1])
  elif kind == dkPlot:
    content = showBase64StringPng(what, size[0], size[1])
  else:
    echo "Unsupported kind for show ", kind
  stdout.write(startmarker, $content, endmarker)
  stdout.flushFile()

template show*(kind:DisplayKind, what:untyped) =
  #TODO: find a way to print only if the current cellId is the executing one
  var content : JsonNode
  when kind == dkTextFile:
    content = showTextFile(what)
  elif kind == dkImageFile:
    content = showImgFile(what)
  elif kind == dkFile:
    content = showBinaryFile(what)
  elif kind == dkPlot:
    content = showBase64StringPng(what, size[0], size[1])
  else:
    echo "Unsupported kind for show ", kind
  
  stdout.write(startmarker, $content, endmarker)
  stdout.flushFile()

proc showText(what: string, mime = "text/plain") =
  let content = %*{
    "data": { mime: what}, # TODO: handle other mimetypes
    "metadata": %* {},
    "transient": %* {}
  }
  stdout.write(startmarker, $content, endmarker)
  stdout.flushFile()

template latex*(str: varargs[string, `$`]) =
  showText("$$" & str.join(" ") & "$$", "text/latex")
  
template md*(str: varargs[string, `$`]) =
  showText(str.join(" "), "text/markdown")
  
template html*(str: varargs[string, `$`]) =
  showText(str.join(" "), "text/html")
  
