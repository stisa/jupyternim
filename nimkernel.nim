import private/sockets, private/messaging
import os,threadpool,zmq

type KernelObj = object
  hb*: Heartbeat # The heartbeat socket object
  shell*: Shell
  pub*: IOPub
  
type Kernel = ref KernelObj

proc init( connmsg : ConnectionMessage) : Kernel =
  echo "[Nimkernel]: Initing"
  new result
  result.hb = createHB(connmsg.ip,connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub( connmsg.ip, connmsg.iopub_port, connmsg.key ) # Initialize iopub 
  result.shell = createShell( connmsg.ip, connmsg.shell_port, connmsg.key, result.pub ) # Initialize shell
  #result.pollitems

proc shutdown(k: Kernel) {.noconv.}=
  echo "[Nimkernel]: Shutting Down"


let arguments = commandLineParams() # [0] should always be the connection file

assert(arguments.len>=1, "[Nimkernel]: Something went wrong, no file passed to kernel?")

var connmsg = arguments[0].parseConnMsg()

var kernel :Kernel = connmsg.init()

#addQuitProc( shutdown(kernel) )

spawn kernel.hb.beat()

var pollers: array[1, TPollItem]
#new pollers
pollers[0].socket = kernel.shell.socket.s
pollers[0].events = ZMQ_POLLIN
#pollers[1].socket = kernel.pub.socket.s
#pollers[1].events = ZMQ_POLLIN

#for i in 0..1:
proc poll2*(items: pointer, nitems: cint, timeout: int): cint{.
  cdecl, importc: "zmq_poll", dynlib: zmqdll.}

while true:
  echo "[Nimkernel]: Waiting on poll..."
  var waiting = poll( addr pollers[0], 1, 10000 )
  echo waiting
  if (waiting == -1): echo errno()
  elif ( waiting != 0 ): # crash???
    #echo "polledINNNNNNNNNNNNNN", pollers[0].revents
    echo "pol",pollers[0]
    #[if pollers[0].revents == 0 :
      kernel.shell.receive()
    if pollers[1].revents == 0 :
      kernel.pub.receive()
]#