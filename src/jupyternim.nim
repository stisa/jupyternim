import ./jupyternimpkg/[sockets, messages, utils]
import os, osproc, threadpool, zmq, json, std/exitprocs
from osproc import execProcess
from strutils import contains, strip

type Kernel = object
  ## The kernel object. Contains the sockets.
  hb: Heartbeat # The heartbeat socket object
  shell: Shell
  control: Control
  pub: IOPub
  running: bool


proc initKernel(connfile: string): Kernel =
  debug "Initing"
  let connmsg = connfile.parseConnMsg()
  if not dirExists(jnTempDir): 
    # Ensure temp folder exists
    createDir(jnTempDir)

  result.hb = createHB(connmsg.ip, connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub(connmsg.ip, connmsg.iopub_port, connmsg.key) # Initialize iopub
  result.shell = createShell(connmsg.ip, connmsg.shell_port, connmsg.key,
      result.pub) # Initialize shell
  result.control = createControl(connmsg.ip, connmsg.control_port,
      connmsg.key) # Initialize iopub
  
  result.running = true

proc shutdown(k: var Kernel) {.noconv.} =
  debug "Shutting Down..."
  k.running = false
  k.hb.close()
  k.pub.close()
  k.shell.close()
  k.control.close()
  if dirExists(jnTempDir):
    removeDir(jnTempDir) # Remove temp dir on exit
    debug "Removed /.jupyternim"

let arguments = commandLineParams() # [0] should always be the connection file

### Install the kernel, executed when running jupyternim directly

if arguments.len < 1: 
  # no connection file passed: assume we're registering the kernel with jupyter
  echo "Installing Jupyter Nim Kernel"
  var pkgDir = execProcess("nimble path jupyternim").strip()
  var (h, t) = pkgDir.splitPath()

  let kernelspec = %*{
    "argv": [ (if t == "src": h else: pkgDir) / "jupyternim",
        "{connection_file}"],
    "display_name": "Nim",
    "language": "nim",
    "file_extension": ".nim"}

  writeFile(pkgDir / "jupyternimspec"/"kernel.json", $kernelspec)
  echo execProcess(r"jupyter-kernelspec install " & pkgDir / "jupyternimspec" &
      " --user") # install the spec
  echo "Finished Installing, try running `jupyter notebook` and select New>Nim"
  quit(0)

#assert(arguments.len>=1, "Something went wrong, no file passed to kernel?")

if arguments.len > 1:
  echo "Unexpected extra arguments:"
  echo arguments

### Main loop: this part is executed when jupyter starts the kernel

var kernel: Kernel = initKernel(arguments[0])

addExitProc(proc(){.noconv.} = kernel.shutdown())

setControlCHook(proc(){.noconv.} =
  kernel.shutdown()
  quit()
) # Hope this fixes crashing at shutdown

proc run(k: Kernel) =
  debug "Starting kernel"
  kernel.pub.sendState("starting")

  spawn kernel.hb.beat()

  while kernel.running:
    if kernel.control.hasMsgs:
      #debug "control..."
      kernel.control.receive()
    
    if kernel.shell.hasMsgs:
      #debug "shell..."
      kernel.shell.receive()
    
    if kernel.pub.hasMsgs:
      #debug "pub..."
      kernel.pub.receive()
    
    sleep(100) # wait a bit before trying again TODO: needed?

kernel.run()