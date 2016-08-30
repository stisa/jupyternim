import zmq,json, messaging, threadpool
#import compiler/nimeval as compiler # We can actually use the nim compiler at runtime! Woho

var execcount {.global.} = 0

type Heartbeat* = object
  socket*: TConnection

type IOPub* = object
  socket*: TConnection
  key*:string
  lastmsg*:WireMessage


type
  ShellObj = object
    socket*: TConnection
    key*: string # session key
    pub*: IOPub # keep a reference to pub so we can send status message
  Shell* = ref ShellObj

proc createHB*(ip:string,hbport:BiggestInt): Heartbeat =
  result.socket = zmq.listen("tcp://"&ip&":"& $hbport)

proc beat*(hb:Heartbeat) =
  while true:
    echo "[Nimkernel]: Reading hb"
    var s = hb.socket.receive() # Read from socket
    echo "[Nimkernel]: Hb read"
    if s!=nil: 
      hb.socket.send(s) # Echo back what we read
    echo "[Nimkernel]: wrote to hb"

proc createIOPub*(ip:string,port:BiggestInt , key:string): IOPub =
  result.socket = zmq.listen("tcp://"&ip&":"& $port,zmq.PUB)
  result.key = key

proc send(pub:IOPub,state:string,) =
  pub.socket.send_wire_msg_no_parent("status", %* { "execution_state": state },pub.key)

proc receive*(pub:IOPub) =
  let recvdmsg : WireMessage = pub.socket.receive_wire_msg()
  echo "[Nimkernel]: pub received:\n", $recvdmsg
  
proc createShell*(ip:string,shellport:BiggestInt,key:string,pub:IOPub): Shell =
  new result
  result.socket = zmq.listen("tcp://"&ip&":"& $shellport, zmq.ROUTER)
  result.key = key
  result.pub = pub

proc handleKernelInfo(s:Shell,m:WireMessage) =
  var content : JsonNode
  spawn s.pub.send("busy") # Tell the client we are busy
  #echo "[Nimkernel]: sending: Kernelinfo sending busy"
  content = %* {
    "protocol_version": "5.0",
    "ipython_version": [1, 1, 0, ""],
    "language_version": [0, 14, 2],
    "language": "nim",
    "implementation": "nimBsd",
    "implementation_version": "0.1",
    "language_info": {
      "name": "nim",
      "version": "0.1",
      "mimetype": "text/x-nimrod",
      "file_extension": ".nim",
      "pygments_lexer": "",
      "codemirror_mode": "",
      "nbconvert_exporter": "",
    },
    "banner": ""
  }
  
  s.socket.send_wire_msg("kernel_info_reply", m , content, s.key)
  #echo "[Nimkernel]: sending kernel info reply and idle"
  spawn s.pub.send("idle") #move to thread

proc handleExecute(shell:Shell,msg:WireMessage) =
  inc execcount
  spawn shell.pub.send("busy") #move to thread
  var code = msg.content["code"].str # The code to be executed
    
  var content = %* {
      "execution_count": execcount,
      "code": code,
  }
  shell.pub.socket.send_wire_msg( "execute_input", msg, content, shell.key)
  #######################################################################
  content = %*{
      "name": "stdout",
      "text": code, # code should be the additional output ( compile messages etc)
  }
  shell.pub.socket.send_wire_msg( "stream", msg, content, shell.key)
  #######################################################################
  content = %*{
      "execution_count": execcount,
      "data": {"text/plain": code }, # code should be the result of the request
      "metadata": {}
  }
  shell.pub.socket.send_wire_msg( "execute_result", msg, content, shell.key)
  #######################################################################
  let status = "ok" # OR 'error' OR 'abort'
  content = %* {
    "status" : status,
    "execution_count" : execcount,
    "payload" : {},
    "user_expressions" : {},
  }
  shell.socket.send_wire_msg("execution_reply", msg , content, shell.key)
  spawn shell.pub.send("idle") #move to thread
  #compiler.execute(code)

proc handleIntrospection(shell:Shell,msg:WireMessage) =
  let code = msg.content["code"].str
  let cpos = msg.content["cursor_pos"].num
  # ask nimsuggest about the code
  var content = %* {
    "status" : "ok", #or "error"
    "found" : false, # found should be true if an object was found, false otherwise
    "data" : {}, #TODO nimsuggest??
    "metadata" : {},
  }
  shell.socket.send_wire_msg("inspect_reply", msg , content, shell.key)

proc handleCompletion(shell:Shell, msg:WireMessage) =
  let code = msg.content["code"].str
  let cpos = msg.content["cursor_pos"].num
  # TODO completion+nimsuggest
  var content = %* {
    # The list of all matches to the completion request, such as
    # ['a.isalnum', 'a.isalpha'] for the above example.
    "matches" : [],
    # The range of text that should be replaced by the above matches when a completion is accepted.
    # typically cursor_end is the same as cursor_pos in the request.
    "cursor_start": 0,
    "cursor_end" : 1,

    # Information that frontend plugins might use for extra display information about completions.
    "metadata" : {},

    # status should be 'ok' unless an exception was raised during the request,
    # in which case it should be 'error', along with the usual error message content
    # in other messages.
    "status" : "ok"
  }
  shell.socket.send_wire_msg("complete_reply", msg , content, shell.key)

proc handleHistory(shell:Shell, msg:WireMessage) =
  echo "[Nimkernel]: Unhandled history"
  var content = %* {
    # A list of 3 tuples, either:
    # (session, line_number, input) or
    # (session, line_number, (input, output)),
    # depending on whether output was False or True, respectively.
    "history" : [],
  }

proc handle(s:Shell,m:WireMessage) =
  if m.msg_type == Kernel_Info:
    handleKernelInfo(s,m)
  elif m.msg_type == Execute:
    handleExecute(s,m)
  elif m.msg_type == Shutdown :
    # TODO quit
    echo "[Nimkernel]: kernel wants to shutdown"
  elif m.msg_type == Introspection : handleIntrospection(s,m)
  elif m.msg_type == Completion : handleCompletion(s,m)
  elif m.msg_type == History : handleHistory(s,m)
  elif m.msg_type == Complete : discard # TODO
  else:
    echo "[Nimkernel]: unhandled message", m

proc receive*(shell:Shell) =
  let recvdmsg : WireMessage = shell.socket.receive_wire_msg()
  echo "[Nimkernel]: sending: ", $recvdmsg.msg_type
  shell.handle(recvdmsg)

type Control* = object
    socket*: TConnection
    key*:string

proc createControl*(ip:string,port:BiggestInt,key:string): Control =
  result.socket = zmq.listen("tcp://"&ip&":"& $port, zmq.ROUTER)
  result.key = key

proc handle(c:Control,m:WireMessage) =
  if m.msg_type == Shutdown:
    var content : JsonNode
    echo "[Nimkernel] shutdown requested"
    content = %* { "restart": false }    
    c.socket.send_wire_msg("shutdown_reply", m , content, c.key)
  #if m.msg_type ==
   
proc receive*(cont:Control) =
  let recvdmsg : WireMessage = cont.socket.receive_wire_msg()
  echo "[Nimkernel]: sending: ", $recvdmsg.msg_type
  cont.handle(recvdmsg)
