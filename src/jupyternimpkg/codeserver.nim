import hotcodereloading, os, strutils

import codecells #the code to be run

template debug*(str: varargs[string, `$`]) =
  when not defined(release):
    let inst = instantiationinfo()
    echo "[" & $inst.filename & ":" & $inst.line & "] ", str.join(" ")

proc codeserver() =
  runNewJupyterCellCode()
  #lastSeenServer = lastSeenCode
  while true:
    if hasModuleChanged(codecells):
      performCodeReload
      debug "#### RELOAD PERFORMED ####"
      runNewJupyterCellCode()
    sleep(1000)
      


      

codeserver() # run the codeserver