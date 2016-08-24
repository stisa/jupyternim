import zmq,json, messaging

type Heartbeat* = object
  socket*: TConnection

proc createHB*(ip:string,hbport:BiggestInt): Heartbeat =
  echo "[Nimkernel]: HB on: tcp://" & ip&":"& $hbport
  result.socket = zmq.listen("tcp://"&ip&":"& $hbport)

proc beat*(hb:Heartbeat) =
  while true:
    echo "[Nimkernel]: Reading hb"
    var s = hb.socket.receive() # Read from socket
    echo "[Nimkernel]: Hb read"
    if s!=nil: 
      hb.socket.send(s) # Echo back what we read
      echo "[Nimkernel]: wrote to hb"

type Shell* = object
  socket*: TConnection
#  stream*: TConnection
  key*: string # session key

proc createShell*(ip:string,shellport:BiggestInt,key:string): Shell =
  result.socket = zmq.listen("tcp://"&ip&":"& $shellport, zmq.ROUTER)
 # result.stream = zmq.connect("tcp://"&ip&":"& $shellport, zmq.DEALER)
  result.key = key
 
proc handle(s:Shell,m:WireMessage) =
  var content : JsonNode
  if m.msg_type == Kernel_Info:
    content = %* {
      "protocol_version": "5.0",
      "ipython_version": [1, 1, 0, ""],
      "language_version": [0, 0, 1],
      "language": "nim",
      "implementation": "nim",
      "implementation_version": "0.1",
      "language_info": {
        "name": "nim",
        "version": "0.1",
        "mimetype": "",
        "file_extension": ".nim",
        "pygments_lexer": "",
        "codemirror_mode": "",
        "nbconvert_exporter": "",
      },
      "banner": ""
    }
    echo "m header ", m.header
    s.socket.send_wire_msg("kernel_info_reply", m , content, s.key)
  elif m.msg_type == Shutdown :
    echo "[Nimkernel]: kernel wants to shutdown"

proc receive*(shell:Shell) =
  #echo "[Nimkernel]: Shell: ", s.socket.receive()
  #shellHandler(s,s.socket.receive())
  let recvdmsg : WireMessage = shell.socket.receive_wire_msg()
  echo "[Nimkernel]: sending: ", $recvdmsg.msg_type
  shell.handle(recvdmsg)
  