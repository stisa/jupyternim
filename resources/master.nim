
#NOTE this file is useless. It should coordinate variable exchange between blocks but it is WAY over my level of competence


discard """import os,dynlib

type
  DynFunc = proc (x: int,argv:varargs[string],envp:varargs[string]):int {.nimcall.}

proc main(x:int,argv:varargs[string],envp:varargs[string]): int =
    if(x<2):
        raiseOSError(osLastError(), "USAGE: "& $argv[0] & " PROGRAM\nWhere PROGRAM is the user's program to supervise\n")
        # exit?
    var handle:LibHandle = loadLib(argv[1])
    var umain: DynFunc = cast[DynFunc]( symAddr(handle, "main") )
    return umain(x,argv,envp)
"""