import hotcodereloading, os

import codecells #the code to be run

proc coderunner() =
  var loadnum = 0
  newCode()
  while true:
    if hasModuleChanged(codecells): 
      echo "# RELOAD PERFORMED ", loadnum
      performCodeReload()
      newCode()
      inc loadnum

coderunner() # run the codeserver