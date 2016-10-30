import private/sockets, private/messaging
import os,threadpool,zmq

type KernelObj = object
  ## The kernel object. Contains the sockets.
  hb*: Heartbeat # The heartbeat socket object
  shell*: Shell
  pub*: IOPub
  control*: Control
  running: bool
  
type Kernel = ref KernelObj

proc init( connmsg : ConnectionMessage) : Kernel =
  debug "Initing"
  new result
  result.hb = createHB(connmsg.ip,connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub( connmsg.ip, connmsg.iopub_port, connmsg.key ) # Initialize iopub 
  result.shell = createShell( connmsg.ip, connmsg.shell_port, connmsg.key, result.pub ) # Initialize shell
  result.control = createControl( connmsg.ip, connmsg.control_port, connmsg.key ) # Initialize iopub 
  
  if not existsDir("inimtemp"): createDir("inimtemp") # Ensure temp folder exists 
  result.running = true

proc shutdown(k: Kernel) {.noconv.}=
  debug "Shutting Down..."
  k.running = false
  k.hb.close()
  k.pub.socket.close()
  k.shell.socket.close()
  k.control.socket.close()
  if existsDir("inimtemp"): 
    debug "Removing inimtemp..."
    removeDir("inimtemp") # Remove temp dir on exit


let arguments = commandLineParams() # [0] should always be the connection file

assert(arguments.len>=1, "Something went wrong, no file passed to kernel?")

var connmsg = arguments[0].parseConnMsg()

var kernel :Kernel = connmsg.init()

addQuitProc(proc(){.noconv.} = kernel.shutdown() )

setControlCHook(proc(){.noconv.} =
  kernel.shutdown()
  quit()
) # Hope this fixes crashing at shutdown

spawn kernel.hb.beat()

debug "Starting to poll..."
while kernel.running:
  if kernel.control.socket.getsockopt(EVENTS) == 3 : kernel.control.receive()
  elif kernel.shell.socket.getsockopt(EVENTS) == 3 : kernel.shell.receive()
  elif kernel.pub.socket.getsockopt(EVENTS) == 3 : kernel.pub.receive()

  else : sleep(100) # wait a bit before trying again