import zmq,json,messages,asyncdispatch

##########################################
# Heartbeat:
type Heartbeat* = object
    socket*: TConnection

proc createHB*(ip:string,hbport:BiggestInt): Heartbeat =
    echo "HB on: tcp://" & ip&":"& $hbport
    result.socket = zmq.listen("tcp://"&ip&":"& $hbport)

proc asyncrecv(c:TConnection):Future[string] {.async.}= 
  result = zmq.receive(c)

proc asyncsend(c:TConnection,msg:string) {.async.}= send(c,msg)

proc beat*(hb:Heartbeat) {.async.}= 

    echo "beat receiving..."
    var s = await asyncrecv(hb.socket) #zmq.receive(hb.socket)
    echo "beat recvd:   " #& $s
    asyncCheck hb.socket.asyncsend(s) #hb.socket.send(s)


##########################################
# Shell:
type Shell* = object
    socket*: zmq.TConnection
    stream*: zmq.TConnection

proc createShell*(ip:string,shellport:BiggestInt): Shell =
    result.socket = zmq.listen("tcp://"&ip&":"& $shellport, zmq.ROUTER)
    result.stream = zmq.connect("tcp://"&ip&":"& $shellport, zmq.DEALER)

proc recv*(s:Shell)= #:Future[string] {.async.} =
    var msg : string = s.socket.receive()
    deserialize(msg)
    #msg.shellhandler

    #TODO shell handler

proc shellHandler(s:Shell,m:auto) =
    var position = 0
    var identities, msg = deserialize(m)
    var content : JObject
    if msg["header"]["msg_type"] == "kernel_info_request":
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
        s.stream.send("kernel_info_reply", content, parent_header=msg["header"], identities=identities)
    
#[]
def shell_handler(msg):
    global execution_count
    dprint(1, "shell received:", msg)
    position = 0
    identities, msg = deserialize_wire_msg(msg)

    # process request:

    if msg['header']["msg_type"] == "execute_request":
        dprint(1, "simple_kernel Executing:", pformat(msg['content']["code"]))
        content = {
            'execution_state': "busy",
        }
        send(iopub_stream, 'status', content, parent_header=msg['header'])
        #######################################################################
        content = {
            'execution_count': execution_count,
            'code': msg['content']["code"],
        }
        send(iopub_stream, 'execute_input', content, parent_header=msg['header'])
        #######################################################################
        content = {
            'name': "stdout",
            'text': "hello, world",
        }
        send(iopub_stream, 'stream', content, parent_header=msg['header'])
        #######################################################################
        content = {
            'execution_count': execution_count,
            'data': {"text/plain": "result!"},
            'metadata': {}
        }
        send(iopub_stream, 'execute_result', content, parent_header=msg['header'])
        #######################################################################
        content = {
            'execution_state': "idle",
        }
        send(iopub_stream, 'status', content, parent_header=msg['header'])
        #######################################################################
        metadata = {
            "dependencies_met": True,
            "engine": engine_id,
            "status": "ok",
            "started": datetime.datetime.now().isoformat(),
        }
        content = {
            "status": "ok",
            "execution_count": execution_count,
            "user_variables": {},
            "payload": [],
            "user_expressions": {},
        }
        send(shell_stream, 'execute_reply', content, metadata=metadata,
            parent_header=msg['header'], identities=identities)
        execution_count += 1
    elif msg['header']["msg_type"] == "kernel_info_request":
        content = {
            "protocol_version": "5.0",
            "ipython_version": [1, 1, 0, ""],
            "language_version": [0, 0, 1],
            "language": "simple_kernel",
            "implementation": "simple_kernel",
            "implementation_version": "1.1",
            "language_info": {
                "name": "simple_kernel",
                "version": "1.0",
                'mimetype': "",
                'file_extension': ".py",
                'pygments_lexer': "",
                'codemirror_mode': "",
                'nbconvert_exporter': "",
            },
            "banner": ""
        }
        send(shell_stream, 'kernel_info_reply', content, parent_header=msg['header'], identities=identities)
    elif msg['header']["msg_type"] == "history_request":
        dprint(1, "unhandled history request")
    else:
        dprint(1, "unknown msg_type:", msg['header']["msg_type"])
    ]#
##############################
# IOPub/Sub:
# aslo called SubSocketChannel in IPython sources
type IOSocket* = object
    pub*: TConnection
    stream*: TConnection

proc createIOSocket*(ip:string,ioport:string): IOSocket =
    result.pub = zmq.listen("tcp://"&ip&":"& $ioport,zmq.PUB)
    result.stream = zmq.listen("tcp://"&ip&":"& $ioport,zmq.STREAM)
    #result.stream.
    #iopub_stream.on_recv(io_handler)

proc recv*(s:IOSocket):string =
    result = s.recv
    # TODO dprint

##########################################
# Control:
type Control* = object
    router*: TConnection
    stream*: TConnection

proc createControl*(ip:string,controlport:string): Control =
    result.router = zmq.listen("tcp://"&ip&":"& $controlport,zmq.ROUTER)
    result.stream = zmq.listen("tcp://"&ip&":"& $controlport,zmq.STREAM)
    #result.stream.
    #iopub_stream.on_recv(io_handler)

proc recv*(s:Control):string =
    var msg = s.recv
    # TODO: identities, msg = deserialize_wire_msg(wire_msg)
    # Control message handler:
    # if msg['header']["msg_type"] == "shutdown_request":
    #    shutdown()

##########################################
# Stdin:
type Stdin* = object
    router*: TConnection
    stream*: TConnection

proc createStdin*(ip:string,stdinport:string): Stdin =
    result.router = zmq.listen("tcp://"&ip&":"& $stdinport,zmq.ROUTER)
    result.stream = zmq.listen("tcp://"&ip&":"& $stdinport,zmq.STREAM)
    #result.stream.
    #iopub_stream.on_recv(io_handler)

proc recv*(s:Stdin):string =
    result = s.recv
    # TODO dprint

##########################################
