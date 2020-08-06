import ./jupyternimpkg/[sockets, messages, utils]
import os, json, std/exitprocs
from osproc import execProcess
from strutils import contains, strip, splitLines

type Kernel = object
  ## The kernel object. Contains the sockets.
  hb: Heartbeat # The heartbeat socket object
  shell: Shell
  control: Control
  pub: IOPub
  sin: StdIn
  running: bool

proc installKernelSpec() =
  ## Install the kernel, executed when running jupyternim directly
  # no connection file passed: assume we're registering the kernel with jupyter
  echo "[Jupyternim] Installing Jupyter Nim Kernel"
  # TODO: assume this can fail, check exitcode
  var pkgDir = execProcess("nimble path jupyternim").strip()
  var (h, t) = pkgDir.splitPath()

  var pathToJN = (if t == "src": h else: pkgDir) / "jupyternim"
  pathToJN = pathToJN.changeFileExt(ExeExt)

  let kernelspec = %*{
    "argv": [pathToJN, "{connection_file}"],
    "display_name": "Nim",
    "language": "nim",
    "file_extension": ".nim"}

  writeFile(pkgDir / "jupyternimspec"/"kernel.json", $kernelspec)
  echo execProcess(r"jupyter-kernelspec install " & pkgDir / "jupyternimspec" &
      " --user") # install the spec
  echo "[Jupyternim] Nim kernel registered, you can now try it in `jupyter lab`"
  quit(0)

proc initKernel(connfile: string): Kernel =
  debug "Initing from: ", connfile, " exists: ", connfile.fileExists
  if not connfile.fileExists:
    debug "Connection file doesn't exit at ", connfile
    quit(1)
  
  let connmsg = connfile.parseConnMsg()
  if not dirExists(jnTempDir): 
    # Ensure temp folder exists
    createDir(jnTempDir)

  result.hb = createHB(connmsg.ip, connmsg.hb_port) # Initialize the heartbeat socket
  result.pub = createIOPub(connmsg.ip, connmsg.iopub_port) # Initialize iopub
  result.shell = createShell(connmsg.ip, connmsg.shell_port,
      result.pub) # Initialize shell
  result.control = createControl(connmsg.ip, connmsg.control_port) # Initialize control
  result.sin = createStdIn(connmsg.ip, connmsg.stdin_port) # Initialize stdin
  
  result.running = true

proc loop(kernel: var Kernel) =
    #spawn kernel.hb.beat()
    debug "Entering main loop"
    while kernel.running:
      # this is gonna crash due to timeouts... or make the pc explode with messages
      
      if kernel.shell.hasMsgs:
        debug "shell..."
        kernel.shell.receive()
      
      if kernel.control.hasMsgs:
        debug "control..."
        kernel.control.receive()
      
      if kernel.pub.hasMsgs:
        debug "pub..."
        kernel.pub.receive()
      
      if kernel.sin.hasMsgs:
        debug "stdin..."
        kernel.sin.receive()

      if kernel.hb.hasMsgs:
        debug "ping..."
        kernel.hb.pong()

      #debug "Looped once"
      sleep(300) # wait a bit before trying again TODO: needed?

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
