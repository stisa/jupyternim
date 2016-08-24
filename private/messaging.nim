import json, strutils, zmq,times,uuid, hmac, nimSHA2,md5

type WireType * = enum
  Unknown  = 0
  Kernel_Info = 1
  Execute = 2
  Status = 9
  Shutdown = 10

type ConnectionMessage * = object 
  ## The connection message the notebook sends when starting
  ip*: string
  signature_scheme*: string
  key*: string
  hb_port*,iopub_port*,shell_port*,stdin_port*,control_port*: int
  kernel_name*: string

proc send_multipart(c:TConnection,msglist:seq[string]) =
  ## sends a message over the connection as multipart.
  for i,msg in msglist:
    var m: TMsg
    if msg_init(m, msg.len) != 0:
        zmqError()

    copyMem(msg_data(m), cstring(msg), msg.len)
    if (i==msglist.len-1):
      if msg_send(m, c.s, 0) == -1: # 0->Last message, not SNDMORE
          zmqError()
    else:
      if msg_send(m, c.s, 2) == -1: # 2->SNDMORE
        zmqError()
    
    # no close msg after a send

proc sign*(msg:string,key:string):string =
  ##Sign a message with a secure signature.
  result = hmac.hmac_sha256(key,msg).hex.toLower

#[
  public string sign(List<string> list) {
            hmac.Initialize();
            foreach (string item in list) {
		byte [] sourcebytes = Encoding.UTF8.GetBytes(item);
                hmac.TransformBlock(sourcebytes, 0, sourcebytes.Length, null, 0);
            }
            hmac.TransformFinalBlock(new byte [0], 0, 0);
	    return BitConverter.ToString(hmac.Hash).Replace("-", "").ToLower();
	}

]#

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
  #[]
  var pre_dicts : string = ""
  while predicts.find("<IDS|MSG>")== -1:
    let rc = c.receive()
    if rc!=nil:
      echo "received: ", rc
      pre_dicts &= rc # Is it even possible to receive empty strings?
  raw.add(predicts[0..^9])
  raw.add(predicts[^9..pre_dicts.high()])

  echo raw[0],"---",raw[1]
]#
  while raw.len<7:
    let rc = c.receive()
    if rc != "":
      raw&=rc

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
      of "shutdown_request" : result.msg_type = WireType.Shutdown
      of "comm_open": echo "[Nimkernel]: useless msg: comm_open"
      of "execute_request": result.msg_type = WireType.Execute
      else: 
        result.msg_type = WireType.Unknown
        echo "Unknown WireMsg: ", result.header # Dump the header for unknown messages 
    else:
      echo "NO WIRE MESSAGE TYPE???????????????"

proc getISOstr*():string = getDateStr()&'T'&getClockStr()
    
proc send_wire_msg*(c:TConnection, reply_type:string, parent:WireMessage,content:JsonNode,key:string) =
  var header: JsonNode = %* {
    "msg_id" : uuid.gen(), # typically UUID, must be unique per message
    "username" : "kernel",
    "session" : key.getmd5(), # using md5 of key as we passed it here already, SECURITY RISK. parent.header["session"], # typically UUID, should be unique per session
    "date": getISOstr(), # ISO 8601 timestamp for when the message is created
    "msg_type" : reply_type,
    "version" : "5.0", # the message protocol version
  }

  var metadata : JSonNode = %* { }

  var reply = @[parent.ident] # Add ident
  
  reply &= "<IDS|MSG>" # add separator
  
  let secondpartreply = $header & $parent.header & $metadata & $content
  reply &= sign(secondpartreply,key) # add signature TODO
  reply &= $header 
  reply &= $parent.header 
  reply &= $metadata 
  reply &= $content
   
  c.send_multipart(reply)
  #echo "[Nimkernel]: sent\n"& $reply[3]
  #for r in reply : c.send(r) # send the reply to jupyter 

proc send_wire_msg_no_parent*(c:TConnection, reply_type:string, content:JsonNode,key:string) =
  var header: JsonNode = %* {
    "msg_id" : uuid.gen(), # typically UUID, must be unique per message
    "username" : "kernel",
    "session" : key.getmd5(), # using md5 of key as we passed it here already, SECURITY RISK. parent.header["session"], # typically UUID, should be unique per session
    "date": getISOstr(), # ISO 8601 timestamp for when the message is created
    "msg_type" : reply_type,
    "version" : "5.0", # the message protocol version
  }

  var metadata : JSonNode = %* { }

  var reply = @["kernel"] # Add ident
  reply &= "<IDS|MSG>" # add separator
  
  let secondpartreply = $header & $ %*{} &  $metadata & $content
  reply &= sign(secondpartreply,key) # add signature TODO
  reply &= $header #3
  reply &= $ %* {}
  reply &= $metadata
  reply &= $content

  c.send_multipart(reply)
  #echo "[Nimkernel]: sent\n"& $reply[3]
  #var rr : string = ""
  #for r in reply: rr&=r # send the reply to jupyter, multi part 
  #c.send(rr)