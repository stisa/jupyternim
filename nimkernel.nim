import private/sockets, private/messaging
import os,threadpool,zmq

type KernelObj = object
  hb*: Heartbeat # The heartbeat socket object
  shell*: Shell
  pub*: IOPub
  control*: Control
  
type Kernel = ref KernelObj

proc init( connmsg : ConnectionMessage) : Kernel =
  echo "[Nimkernel]: Initing"
  new result
  result.hb = createHB(connmsg.ip,connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub( connmsg.ip, connmsg.iopub_port, connmsg.key ) # Initialize iopub 
  result.shell = createShell( connmsg.ip, connmsg.shell_port, connmsg.key, result.pub ) # Initialize shell
  result.control = createControl( connmsg.ip, connmsg.control_port, connmsg.key ) # Initialize iopub 
  #result.pollitems

proc shutdown(k: Kernel) {.noconv.}=
  echo "[Nimkernel]: Shutting Down"


let arguments = commandLineParams() # [0] should always be the connection file

assert(arguments.len>=1, "[Nimkernel]: Something went wrong, no file passed to kernel?")

var connmsg = arguments[0].parseConnMsg()

var kernel :Kernel = connmsg.init()

#addQuitProc( shutdown(kernel) )

spawn kernel.hb.beat()

#proc poll(k:Kernel): bool =
#  if k.pub.getsockopt(EVENTS) == 3 : return true
#  elif k.shell.getsockopt(EVENTS) == 3 : return true
#  else : sleep(100) # wait a bit before trying again

echo "[Nimkernel]: Starting to poll..."
while true:
  #echo "[Nimkernel]: Waiting on poll..."
  if kernel.control.socket.getsockopt(EVENTS) == 3 : kernel.control.receive()
  elif kernel.shell.socket.getsockopt(EVENTS) == 3 : kernel.shell.receive()
  elif kernel.pub.socket.getsockopt(EVENTS) == 3 : kernel.pub.receive()

  else : sleep(100) # wait a bit before trying again