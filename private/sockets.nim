import zmq

##########################################
# Heartbeat:
type Heartbeat* = object
    socket*: TConnection

proc createHB*(ip:string,hbport:string): Heartbeat =
    result.socket = zmq.connect(ip&hbport)

proc beat*(hb:Heartbeat):bool = 
    var s :string = zmq.receive(hb.socket)
    hb.socket.send(s)
    # if we haven't errored
    result = true

##########################################
# IOPub/Sub:
# aslo called SubSocketChannel in IPython sources
type IOSocket* = object
    pub*: TConnection
    stream*: TConnection

proc createIOSocket*(ip:string,ioport:string): IOSocket =
    result.pub = zmq.connect(ip&ioport,zmq.PUB)
    result.stream = zmq.connect(ip&ioport,zmq.STREAM)
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
    result.router = zmq.connect(ip&controlport,zmq.ROUTER)
    result.stream = zmq.connect(ip&controlport,zmq.STREAM)
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

proc createStdin*(ip:string,ioport:string): Stdin =
    result.router = zmq.connect(ip&ioport,zmq.ROUTER)
    result.stream = zmq.connect(ip&ioport,zmq.STREAM)
    #result.stream.
    #iopub_stream.on_recv(io_handler)

proc recv*(s:Stdin):string =
    result = s.recv
    # TODO dprint

##########################################
# Shell:
type Shell* = object
    socket*: zmq.TConnection
    stream*: zmq.TConnection

proc createShell*(ip:string,shellport:string): Shell =
    result.socket = zmq.connect(ip&shellport, zmq.ROUTER)
    result.stream = zmq.connect(ip&shellport, zmq.STREAM)

proc recv*(s:Shell):string =
    var msg = s.recv
    msg.shellhandler
    #TODO shell handler
