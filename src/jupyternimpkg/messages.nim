import json, options, strutils
import hmac, nimSHA2
import ./utils


type 
  WireType* = enum
    Unknown,
    
    kernel_info_request,
    execute_request,
    inspect_request,
    completion_request,
    history_request,
    complete_request,
    comm_info_request,
    shutdown_request,
    input_request,
    interrupt_request, # 5.3
    debug_request, # 5.5

    kernel_info_reply,
    execute_reply,
    inspect_reply,
    completion_reply,
    history_reply,
    complete_reply,
    comm_info_reply,
    shutdown_reply,
    input_reply,
    interrupt_reply,
    debug_reply # 5.5s

    status,
    execute_result,
    stream,
    display_data,
    update_display_data,
    execute_input,
    error,
    clear_output,
    debug_event, # 5.5
    comm_open
    comm_close
    comm_msg
  
  WireMessage* = object
    #msg_type: WireType # Convenience, this is not part of the spec
    ## Describes a raw message as passed by Jupyter/Ipython
    ## Follows https://jupyter-client.readthedocs.io/en/stable/messaging.html#the-wire-protocol
    ident: string      # uuid
    signature: string  # hmac signature
    header: WireHeader
    parent_header: Option[WireHeader]
    metadata*: JsonNode
    content*: JsonNode
    buffers*: string      # Extra raw data

  WireHeader* = object
    msg_id : string # typically UUID, must be unique per message
    session: string # typically UUID, should be unique per session
    username : string
    date: string # ISO 8601 timestamp for when the message is created
    msg_type : WireType
    version : string # '5.3', the message protocol version

  ConnectionFile* = object
    ## The connection file the notebook sends when starting
    ip*: string
    transport*: string
    signature_scheme*: string
    key*: string
    hb_port*, iopub_port*, shell_port*, stdin_port*, control_port*: int
    #not specced: kernel_name*: string

var ConnKey: string # Key used to sign messages

proc parseConnMsg*(connfile: string): ConnectionFile =
  result = parseFile(connfile).to(ConnectionFile)
  ConnKey = result.key
  setupFileNames() # update the filenames on kernel start 
  debug "FROM MESSAGES: ", JNfile, " out ", JNoutCodeservername
  debug result

proc initHeader(msg_id, date: string, msg_type:WireType): WireHeader =
  WireHeader( msg_id: msg_id, session:JNsession, username:JNuser, date:date, 
              msg_type: msg_type, version: $JNprotocolVers)

proc kind*(m: WireMessage): WireType = m.header.msg_type

proc decode*(raw: openarray[string]): WireMessage =
  ## decoedes a wire message as a seq of string blobs into a WireMessage object
  ## FIXME: only handles the first 7 parts, the extra raw data is buggy
  result.ident = raw[0]
  #debug "IN"
  #debug raw
  if len(raw)>7:
    debug "BUFFERS", raw[8]

  doAssert(raw[1] == "<IDS|MSG>", "Malformed message follows:\n" & $raw & "\nMalformed message ends\n")

  result.signature = raw[2]
  try:
    result.header = parseJson(raw[3]).to(WireHeader)
  except KeyError as e:
    var jsonheader = parseJson(raw[3]) 
    debug e.msg, "json: ", parseJson(raw[3])
    #if spec 5.2 date isn't here???
    jsonheader["date"] = % ""
    result.header = jsonheader.to(WireHeader)
  try:
    result.parent_header = some(parseJson(raw[4]).to(WireHeader))
  except KeyError as e:
    var jsonheader = parseJson(raw[4])
    debug e.msg, "parent json: ", jsonheader
    result.parent_header = none(WireHeader)
  result.metadata = parseJson(raw[5])
  result.content = parseJson(raw[6])
  
  debug "METADATA", result.metadata
  
  if result.kind == Unknown:
    debug "unhandled msg_type ", result.kind, " rawfollows:" # Dump unknown messages
    debug $raw
    debug "unhandled msg_type end"

proc sign(msg: WireMessage, key: string): string =
  var encodedParent = "{}"
  if msg.parent_header.isSome:
    encodedParent = $(%* msg.parent_header.get)
  let partToSign = $(%* msg.header) & encodedParent & $msg.metadata & $msg.content
  result = hmac.hmac_sha256(key, partToSign).hex.toLowerAscii
  
proc encode*(msg: WireMessage, key: string = ConnKey): seq[string] =
  ## Encode a message following wire spec, into a seq of strings
  
  var encodedParent: string = "{}" # start as empty json obj
  if msg.parent_header.isSome:
    encodedParent = $(%* msg.parent_header.get)

  result = @[msg.ident]
  result &= "<IDS|MSG>" # add separator

  result &= sign(msg, key)
  result &= $(%* msg.header)
  result &= encodedParent
  result &= $msg.metadata
  result &= $msg.content
  #result &= "{}" #empty buffers

  #debug "OUT"
  #debug result

type
  PubMsg* = WireMessage
  ShellMsg* = WireMessage
  ControlMsg* = WireMessage
  StdInMsg* = WireMessage

  Status* {.pure.} = enum
    ok
    error
  State* {.pure.} = enum
    starting
    idle
    busy

const iopubTopics = { execute_result , stream, display_data, update_display_data,
                    execute_input, error, status, clear_output, debug_event }

proc setupMsg(msg: var WireMessage, kind: WireType, 
              parent: Option[WireMessage] = none(WireMessage)) =
  msg = WireMessage()

  if msg.kind in iopubTopics: msg.ident = $msg.kind
  msg.header = initHeader(genUUID(), getISOstr(), kind)  
  msg.metadata = %* {}
  
  if parent.isSome:
    msg.ident = parent.get.ident
    msg.parent_header = parent.get.header.some  
    msg.metadata = parent.get.metadata
  debug "IS IDENT EMPTY? ", (msg.kind notin iopubTopics) and parent.isNone
  #sign?
  
proc kernelInfoMsg*(parent: WireMessage): ShellMsg =
  result.setupMsg(kernel_info_reply, parent.some)
  result.content = %* {
    "protocol_version": $JNprotocolVers,
    "implementation": "jupyternim",
    "implementation_version": JNKernelVersion,
    "language_info": {
      "name": "nim",
      "version": NimVersion,
      "mimetype": "text/x-nim",
      "file_extension": ".nim",
    },
    "banner": ""
  }
proc replyErrorMsg*(exec_count: int, errname, errvalue: string,
              tracebacks: seq[string]= @[], 
              parent: WireMessage): ShellMsg =
  result.setupMsg(execute_reply, parent.some)
  result.content = %* {
    "status": Status.error,
    "execution_count": exec_count,
    "ename": errname, # Exception name, as a string
    "evalue": errvalue, # Exception value, as a string TODO: get this from the comp.out
    "traceback": tracebacks, # traceback frames as strings
  }
  result.metadata["status"] = % Status.error # jupyterlab does it

proc replyErrorMsg*(forMsg:WireType, errname, errvalue: string,
              tracebacks: seq[string]= @[], exec_count: int = 0,
              parent: WireMessage): ShellMsg =
  
  assert(forMsg in {inspect_reply, complete_reply})
  result.setupMsg(forMsg, parent.some)
  result.content = %* {
    "status": Status.error,
    "ename": errname,
    "evalue": errvalue,
    "traceback": tracebacks
  }

proc execResultMsg*( count: int, data: string, # or JsonNode? 
                    parent: Option[WireMessage]=none(WireMessage)): ShellMsg =
  # show from display.nim ought to be handled here too?
  result.setupMsg(execute_result, parent)
  result.content = %*{
      "execution_count": count,
      "data": {"text/plain": data},
      "metadata": %*{}
  }

proc displayExecResMsg*(count: int, ddcontent: JsonNode, 
                    parent: Option[WireMessage]=none(WireMessage)): PubMsg =
  # we expect to mostly see this from the display module, so content is 
  # already complete, but in string form
  result.setupMsg(execute_result, parent)
  result.content = ddcontent
  result.content["execution_count"] = % count
  result.content["metadata"] = %* {}

proc execReplyMsg*(count: int, status: Status, # or JsonNode? 
                  parent: WireMessage): ShellMsg =
  result.setupMsg(execute_reply, parent.some)
  result.content = %* {
    "status": status,
    "execution_count": count,
    #"payload": {}, # payloads are deprecated
    "user_expressions": %*{}
  }

proc inspectReplyMsg*( status: Status, found: bool = false, 
                      data: JsonNode = %* {}, metadata: JsonNode = %* {},
                      parent: Option[WireMessage]): ShellMsg=
  result.setupMsg(inspect_reply, parent)
  result.content = %* {
    "status": $status,
    "found": found, # found should be true if an object was found, false otherwise
    "data": data,     #TODO nimsuggest??
    "metadata": metadata,
  }

proc completeReplyMsg*(status: Status, matches: seq[string],
                      cursorSt, cursorEnd: int,
                      parent: Option[WireMessage],
                      metadata: JsonNode = %* {}): ShellMsg=
  result.setupMsg(complete_reply, parent)
  result.content = %* {
    # The list of all matches to the completion request
    "matches": matches,
    # The range of text that should be replaced by the above matches when a completion is accepted.
    # typically cursor_end is the same as cursor_pos in the request.
    "cursor_start": cursorSt,
    "cursor_end": cursorEnd, # re add 1 to match cursor_pos
    # Information that frontend plugins might use for extra display information about completions.
    "metadata": metadata,
    "status": status
  }
  # debug msg
  
proc historyReplyMsg*( history: JsonNode, parent: Option[WireMessage],
                      metadata: JsonNode = %* {}): ShellMsg=
  echo "[Jupyternim] Unimplemented: history_request" # TODO: error?
  assert(parent.isSome)
  result.setupMsg(history_reply, parent)
  result.content = %* {
      # A list of 3 tuples, either:
      # (session, line_number, input) or
      # (session, line_number, (input, output)),
      # depending on whether output was False or True, respectively.
    "history": history,
  }
  
proc commReplyMsg*(parent: Option[WireMessage]=none(WireMessage),
                      metadata: JsonNode = %* {}): ShellMsg=
  echo "[Jupyternim] Unimplemented: history_request" # TODO: error?
  result.setupMsg(comm_info_reply, parent)
  #[content = {  'comms': { comm_id: { 'target_name': str,  },    }, }]#
  result.content = %* { "comms": %* {} } # TODO: care

### IOPub Messages

proc statusMsg*( s: State, 
                parent: Option[WireMessage] = none(WireMessage)): PubMsg =
  result.setupMsg(status, parent)
  result.content = %* {"execution_state": s}

proc executeInputMsg*(count:int, code: string, 
                parent: Option[WireMessage]=none(WireMessage)): PubMsg =
  result.setupMsg(execute_input, parent)
  result.content = %* {
    "execution_count": count,
    "code": code,
  }

proc streamMsg*( streamname, text: string, 
                parent: Option[WireMessage]=none(WireMessage)): PubMsg =
  result.setupMsg(stream, parent)
  result.content = %*{
    "name": streamName, 
    "text": text
  }

proc errorMsg*(errname, errvalue: string,
              tracebacks: seq[string]= @[],
              parent: Option[WireMessage]=none(WireMessage)): PubMsg=
  result.setupMsg(WireType.error, parent)
  result.content = %* {
    "ename": errname, # Exception name, as a string
    "evalue": errvalue, # Exception value, as a string TODO: get this from the comp.out
    "traceback": tracebacks, # traceback frames as strings
  }

proc displayDataMsg*(ddcontent: JsonNode, 
                    parent: Option[WireMessage]=none(WireMessage)): PubMsg =
  # we expect to mostly see this from the display module, so content is 
  # already complete, but in string form
  result.setupMsg(display_data, parent)
  result.content = ddcontent

proc shutdownMsg*(kind: WireType, parent: Option[WireMessage]): ControlMsg =
  # either shutdown or interrupt message
  # TODO: handle restart?
  assert(parent.isSome)
  if kind == shutdown_request:
    result.setupMsg(shutdown_reply, parent)
    result.content = parent.get.content
  else:
    result.setupMsg(interrupt_reply, parent)
  
  
proc inputReqMsg*(inputmsg:string): StdInMsg =
  result = StdInMsg()
  result.ident = genUUID()#ident?
  #sign?
  result.header = initHeader(genUUID(), getISOstr(),  input_request)
  result.parent_header = none(WireHeader)
  result.metadata = %*{}
  result.content = %* { 
    # the text to show at the prompt
    "prompt": inputmsg,
    # Is the request for a password?
    # If so, the frontend shouldn't echo input.
    "password" : false
  }

#[
  
type 
  CommKind {.pure.} = enum
    Open, Close, Msg
  Comm = object
    comm_id: string # 'u-u-i-d',
    data : JsonNode # {}
    case kind: CommKind
    of CommKind.Open:
      target_name*: string # 'my_comm', only for comm_open
    else: discard


proc openComm(target: string, data: JsonNode = %* {} ): Comm =
  result = Comm(kind: CommKind.Open, comm_id: genUUID(), target_name: target, data: data)

proc comm(c: Comm, data: JsonNode = %* {}): Comm =
  result = Comm(kind: CommKind.Msg, comm_id: c.comm_id, data: data)

proc closeComm(c: Comm, data: JsonNode = %* {}): Comm =
  result = Comm(kind: CommKind.Close, comm_id: c.comm_id, data: data)

]#