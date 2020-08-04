import json, utils, options

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
    
    kernel_info_reply,
    execute_reply,
    inspect_reply,
    completion_reply,
    history_reply,
    complete_reply,
    comm_info_reply,
    shutdown_reply,

    status,
    execute_result,
    stream,
    display_data,
    update_display_data,
    execute_input,
    error,
    clear_output,
    debug_event,
    comm_open
    comm_close
    comm_msg
  
  WireMessage* = object
    msg_type*: WireType # Convenience, this is not part of the spec
    ## Describes a raw message as passed by Jupyter/Ipython
    ## Follows https://jupyter-client.readthedocs.io/en/stable/messaging.html#the-wire-protocol
    ident*: string      # uuid
    signature*: string  # hmac signature
    header*: WireHeader
    parent_header*: Option[WireHeader]
    metadata*: JsonNode
    content*: JsonNode
    buffers*: string      # Extra raw data

  WireHeader* = object
    msg_id* : string # typically UUID, must be unique per message
    session: string # typically UUID, should be unique per session
    username : string
    date: string # ISO 8601 timestamp for when the message is created
    msg_type : WireType
    version : string # '5.3', the message protocol version

  ConnectionMessage* = object
    ## The connection message the notebook sends when starting
    ip*: string
    transport*: string
    signature_scheme*: string
    key*: string
    hb_port*, iopub_port*, shell_port*, stdin_port*, control_port*: int
    #not specced: kernel_name*: string

var ConnKey: string
let JNsession = genUUID()
const JNuser = "kernel"
const ProtocolVers = 5.3

const iopubTopics = { execute_result , stream, display_data, update_display_data,
                    execute_input, error, status, clear_output, debug_event }

proc parseConnMsg*(connfile: string): ConnectionMessage =
  result = parseFile(connfile).to(ConnectionMessage)
  ConnKey = result.key
  debug result

proc initHeader(msg_id, session, user, date: string, msg_type:WireType, version: float): WireHeader =
  WireHeader(msg_id: msg_id, session:session, username:user, date:date, msg_type: msg_type, version: $version)

proc decode*(raw: openarray[string]): WireMessage =
  ## decoedes a wire message as a seq of string blobs into a WireMessage object
  ## FIXME: only handles the first 7 parts, the extra raw data is discarded
  result.ident = raw[0]

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
    debug e.msg, "json: ", jsonheader
    result.parent_header = none(WireHeader)
  result.metadata = parseJson(raw[5])
  result.content = parseJson(raw[6])
  
  debug "METADATA", result.metadata
  result.msg_type = result.header.msg_type

  if result.msg_type == Unknown:
    debug "unhandled msg_type ", result.msg_type, " rawfollows:" # Dump unknown messages
    debug $raw
    debug "unhandled msg_type end"

proc encode*(reply_type: WireType, content: JsonNode, 
    parent: varargs[WireMessage], key: string = ConnKey): seq[string] =
  #TODO: split into encodemsg and createmsg
  ## Encode a message following wire spec
  
  var identities : string = ""
  let header = initHeader(genUUID(), JNsession, JNuser, getISOstr(), reply_type, 5.3)

  #[let header: JsonNode = %* {
    "msg_id": genUUID(), # typically UUID, must be unique per message
    "username": "kernel",
    "session": key.getmd5(), # using md5 of key as we passed it here already, SECURITY RISK?
    "date": getISOstr(), # ISO 8601 timestamp for when the message is created
    "msg_type": reply_type, # TODO: use an enum?
    "version": "5.3",    # the message protocol version
  }]#

  var
    metadata: JSonNode = %* {}
    parentHeader: WireHeader
    encodedParent: string = "{}"
  if parent.len != 0:
    identities = parent[0].ident
    # TODO: check parent header wasn't empty
    parentHeader = parent[0].header
    encodedParent = $(%* parentHeader)

  if  reply_type in iopubTopics: 
    # FIXME: IOPUB has special treatment RE: idents see
    # https://jupyter-client.readthedocs.io/en/stable/messaging.html#the-wire-protocol
    identities = $reply_type
  
  # TODO: if parent header is empty, should it be serialized to empty dict??
  result = @[identities]
  result &= "<IDS|MSG>" # add separator

  let partToSign = $(%* header) & encodedParent & $metadata & $content
  result &= sign(partToSign, key)
  result &= $(%* header)
  result &= encodedParent
  result &= $metadata
  result &= $content

type 
  CommKind {.pure.} = enum
    Open, Close, Msg
  Comm* = object
    comm_id*: string # 'u-u-i-d',
    data* : JsonNode # {}
    case kind: CommKind
    of CommKind.Open:
      target_name*: string # 'my_comm', only for comm_open
    else: discard


proc openComm*(target: string, data: JsonNode = %* {} ): Comm =
  result = Comm(kind: CommKind.Open, comm_id: genUUID(), target_name: target, data: data)

proc comm*(c: Comm, data: JsonNode = %* {}): Comm =
  result = Comm(kind: CommKind.Msg, comm_id: c.comm_id, data: data)

proc closeComm*(c: Comm, data: JsonNode = %* {}): Comm =
  result = Comm(kind: CommKind.Close, comm_id: c.comm_id, data: data)
