import json, strutils, zmq,times,uuid

type WireType * = enum
  Unknown  = -1,
  Kernel_Info = 0

type ConnectionMessage * = object 
  ## The connection message the notebook sends when starting
  ip*: string
  signature_scheme*: string
  key*: string
  hb_port*,iopub_port*,shell_port*,stdin_port*,control_port*: int
  kernel_name*: string

proc parseConnMsg*(connfile:string):ConnectionMessage =
  #var connectionfile = connfile.readFile
  let parsedconn = parseFile(connfile)
  result.ip = parsedconn["ip"].str
  result.signature_scheme = parsedconn["signature_scheme"].str
  result.key = parsedconn["key"].str
  result.hb_port = parsedconn["hb_port"].num.int
  result.iopub_port = parsedconn["iopub_port"].num.int
  result.shell_port = parsedconn["shell_port"].num.int
  result.stdin_port = parsedconn["stdin_port"].num.int
  result.control_port = parsedconn["control_port"].num.int
  result.kernel_name = parsedconn["kernel_name"].str

proc `$`*(cm:ConnectionMessage):string=
  result = "ip: "& cm.ip &
            "\nsignature_scheme: "&cm.signature_scheme&
            "\nkey: "&cm.key&
            "\nhb_port: " & $cm.hb_port&
            "\niopub_port: "& $cm.iopub_port&
            "\nshell_port: "& $cm.shell_port&
            "\nstdin_port: "& $cm.stdin_port&
            "\ncontrol_port: "& $cm.control_port&
            "\nkernel_name: "&cm.kernel_name

type WireMessage * = object
  msg_type*: WireType # Convenience, this is not part of the spec
  ## Describes a raw message as passed by Jupyter/Ipython
  ident*: string # uuid
  signature*:string # hmac signature
  header*: JsonNode
  parent_header*: JsonNode
  metadata*: JsonNode
  content*: JsonNode

proc receive_wire_msg*(c:TConnection):WireMessage =
  var raw : seq[string] = @[]
  
  while raw.len<7:
    let rc = c.receive()
    if rc != "":
      raw &= rc # Is it even possible to receive empty strings?
  
  result.ident = raw[0]
  if( raw[1]!="<IDS|MSG>"): 
    echo "[Nimkernel]:proc receive wire msg: Malformed message?? Follows:"
    echo "[Nimkernel]: ",raw
  else :
    result.signature = raw[2]
    result.header = parseJson(raw[3])
    result.parent_header = parseJson(raw[4])
    result.metadata = parseJson(raw[5])
    result.content = parseJson(raw[6])
    if result.header.hasKey("msg_type") : 
      case result.header["msg_type"].str:
      of "kernel_info_request": result.msg_type = WireType.Kernel_Info
      of "comm_open": echo "[Nimkernel]: useless msg: comm_open"
      else: 
        result.msg_type = WireType.Unknown
        echo "Unknown WireMsg: ", result.header # Dump the header for unknown messages 

proc getISOstr*():string = getDateStr()&'T'&getClockStr()
    
proc send_wire_msg*(c:TConnection, reply_type:string, parent:WireMessage,content:JsonNode,key:string) =
  var reply : string = ""
  reply &= parent.ident # Add ident
  reply &= "<IDS|MSG>" # add separator
  reply &= " " # add signature TODO
  #if parent.header.hasKey("username"): 
  #  phu = parent.header["username"]
  #else: echo "[Nimkernel]: NIMNOUSER"
  if ( parent.header["session"]!=nil):
    echo "[Nimkernel]: ", parent.header["session"]
    var ss = parent.header["session"].str
  var header: JsonNode = %* {
    "msg_id" : uuid.gen(), # typically UUID, must be unique per message
    "username" : "username",
    "session" : ss, # typically UUID, should be unique per session
    "date": getISOstr(), # ISO 8601 timestamp for when the message is created
    "msg_type" : reply_type, # All recognized message type strings are listed below.
    "version" : "5.0", # the message protocol version
  }

  reply &= $header # add header

  reply &= $parent.header # add parent header
  
  reply &= "{}" # metadata
  
  reply &= $content # Add content

  c.send(reply) # send the reply to jupyter 


#var prsmsg : 
proc deserialize*(msg:string):JsonNode =#: tuple[ id:string, m: JsonNode] =
    #let delim_ind = msg.find()
    echo "startmes--------------"
    echo msg
  #  if (msg[0]=='{'):
  #    var parsedmsg : JsonNode = parseJson(msg)
  #    echo "parsed",parsedmsg
  #  elif msg[0]!=' ':
  #    var splitted = msg.split("<IDS|MSG>")
   # var identities = splitted[0]
   # var m_signature = splitted[1].split("\n") 
    #var m_frames = splitted[1][1..high(splitted[1])]
    #var m : JsonNode
    #echo "splited"
    #echo splitted
    #echo "ident"
   # echo identities
    #echo "newlnied"
  #  echo m_signature
    echo "endmes-----------------------"