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

proc runKernel(connfile:string) =
  ## Main loop: this is executed when jupyter starts the kernel
  
  var kernel: Kernel = initKernel(connfile)

  addExitProc(proc() = kernel.shutdown())
  setControlCHook(proc(){.noconv.}=quit())
  
  kernel.loop()

let arguments = commandLineParams() # [0] is ususally the connection file
case arguments.len:
of 0: # no args, assume we are installing the kernel
  installKernelSpec()
of 1:
  if arguments[0] == "-v":
    echo "Jupyternim version: ", JNKernelVersion
  elif arguments[0][^4..^1] == "json": # TODO: file splitFile bug with C:\Users\stisa\AppData\Roaming\jupyter\runtime\kernel-9f74a25e-d932-4212-98ae-693f8d18ed55.json
    runKernel(arguments[0])
  else:
    echo "Unrecognized single argument: ", arguments[0]
else:
  echo "More than expected arguments: ", $arguments
  if arguments[0][^2..^1] == "py": quit(1) # vscode-python shenanigans

quit(0)
