import ./jupyternimpkg/[sockets, messages]
import os,threadpool,zmq, json, std/exitprocs
from osproc import execProcess
from strutils import contains, strip

type Kernel = object
  ## The kernel object. Contains the sockets.
  hb*: Heartbeat # The heartbeat socket object
  shell*: Shell
  pub*: IOPub
  control*: Control
  running: bool
  

proc init( connmsg : ConnectionMessage) : Kernel =
  debug "Initing"
  result.hb = createHB(connmsg.ip,connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub( connmsg.ip, connmsg.iopub_port, connmsg.key ) # Initialize iopub 
  result.shell = createShell( connmsg.ip, connmsg.shell_port, connmsg.key, result.pub ) # Initialize shell
  result.control = createControl( connmsg.ip, connmsg.control_port, connmsg.key ) # Initialize iopub 
  
  if not dirExists("inimtemp"): createDir("inimtemp") # Ensure temp folder exists 
  result.running = true

proc shutdown(k: var Kernel) {.noconv.}=
  debug "Shutting Down..."
  k.running = false
  k.hb.close()
  k.pub.socket.close()
  k.shell.socket.close()
  k.control.socket.close()
  if dirExists("inimtemp"): 
    debug "Removing inimtemp..."
    removeDir("inimtemp") # Remove temp dir on exit


let arguments = commandLineParams() # [0] should always be the connection file

if arguments.len < 1:
  echo "Installing Jupyter Nim Kernel"
  var pkgDir = execProcess("nimble path jupyternim").strip()
  var (h,t) = pkgDir.splitPath()
  
  let kernelspec = %*{
    "argv": [ (if t == "src": h else: pkgDir) / "jupyternim",  "{connection_file}"],
    "display_name": "Nim",
    "language": "nim",
    "file_extension": ".nim" }

  writeFile(pkgDir / "jupyternimspec"/"kernel.json", $kernelspec)
  echo execProcess(r"jupyter-kernelspec install " & pkgDir / "jupyternimspec" & " --user") # install the spec
  echo "Finished Installing, try running `jupyter notebook` and select New>Nim"
  quit(0)
#assert(arguments.len>=1, "Something went wrong, no file passed to kernel?")

var connmsg = arguments[0].parseConnMsg()

var kernel :Kernel = connmsg.init()

addExitProc(proc(){.noconv.} = kernel.shutdown() )

setControlCHook(proc(){.noconv.} =
  kernel.shutdown()
  quit()
) # Hope this fixes crashing at shutdown

spawn kernel.hb.beat()

debug "Starting to poll..."
while kernel.running:
  if getsockopt[int](kernel.control.socket,EVENTS) == 3 : kernel.control.receive()
  elif getsockopt[int](kernel.shell.socket,EVENTS) == 3 : kernel.shell.receive()
  elif getsockopt[int](kernel.pub.socket,EVENTS) == 3 : kernel.pub.receive()

  else : sleep(100) # wait a bit before trying again
