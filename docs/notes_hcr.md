# Implementing hotcodereloading in jupyternim

Main jupyternim running loop

external code loop (`nimcodeloop.exe`)
```nim
# nimcodeloop.nim

import hotcodereloading

import $inimtemp/nimcode # < code to be run goes here

proc main() =
  while true:
    if hasAnyModuleChanged(): performCodeReload()

main()
```

nim code to be run
```nim
# nimcode.nim
import hotcodereload # hidden

afterCodeReload:     # hidden
  var x = 124   
  echo x+124 #> 248 
```

add a code cell
```nim
x = 125
```
rerun the module
```nim
# nimcode.nim
import hotcodereload # hidden
var x = 124          # hidden
echo x+124 #> 248    # hidden

afterCodeReload:
  x = 126
  echo x+124 #> 250
```


## Suggestion to avoid problems

### Use a separate cell to declare variables
```nim
  # cell 1
  var 
    x: float
    y: int
  # next cell (cell 2)
  x = 123
  y = 12.6
  echo x, y
  # next cell (cell 3)
  x = 256
  echo x
```

### No changing variable type
Due to implementation limitations of hotcodereloading, changing
the variable type is forbidden
```nim
  # cell 1
  var x = 125
  # update cell 1, run
  var x = 12.6 #> error!
```
