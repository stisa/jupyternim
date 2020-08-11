import strutils, times, random, nimSHA2, md5, zmq, os

template debug*(str: varargs[string, `$`]) =
  when not defined(release):
    let inst = instantiationinfo()
    stderr.writeLine("[" & $inst.filename & ":" & $inst.line & "] ", str.join(" "))
    stderr.flushFile
  else:
    discard

const validx = ['A', 'B', 'C', 'D', 'E', 'F', 
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
const validy = ['8', '9', '0', 'B']

proc genUUID*(nb:bool=false, upper: bool = false): string =
  ## Generate a uuid version 4.
  ## If ``nb`` is false, the uuid is compatible with IPython console.
  randomize()
  result = if nb: "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx" else: "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  for c in result.mitems:
    if c == 'y': c = sample(validy)
    elif c == 'x': c = sample(validx)
  if not upper: result = result.toLowerAscii

proc getISOstr*(): string = getDateStr()&'T'&getClockStr()

proc flatten*(flags: openArray[string]): string =
  result = " "
  for f in flags: result.add(f&" ")

proc send_multipart*(c: TConnection, msglist: openArray[string]) =
  ## sends a message over the connection as multipart.
  for i, msg in msglist:
    let flag = if i != msglist.len-1: SNDMORE else: NOFLAGS
    c.send(msg,flag)

proc recv_multipart*(c: TConnection): seq[string] =
  result = @[]
  var hasMore = true
  while hasMore:
    #debug "HASMORE: ", hasMore
    let rc = c.s.receive()
    if rc != "": 
      result &= rc
    if getsockopt[int](c.s, RCVMORE) == 0:
      # if RCVMORE == 0, this is either a single message or 
      # we reached the last frame
      hasMore = false
  # debug "RECV MULTIPART LEN: ", result.len

proc filter*[T](seq1: openarray[T], 
                pred: proc(item: T): bool {.closure.}): seq[T] {.inline.} =
  ## Returns a new sequence with all the items that fulfilled the predicate.
  ## Copied from sequtils, modified to work with openarray
  result = newSeq[T]()
  for i in 0..<seq1.len:
    if pred(seq1[i]):
      result.add(seq1[i])

# Useful constants
const 
  JNKernelVersion* = "0.5.8" # should match the one in the nimble file
  JNuser* = "kernel"
  JNprotocolVers* = 5.3
var 
  JNsession*: string # = genUUID() # not a const, we want it to change with every run
  JNfile* : string # = "n" & JNsession.replace('-','n') # not a const, we want it to change with every run
  JNoutCodeServerName* : string

proc setupFileNames* () =
  JNsession = genUUID()
  JNfile = "n" & JNsession.replace('-','n')
  JNoutCodeservername = JNfile.changeFileExt(ExeExt)