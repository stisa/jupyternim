import os,dynlib

type
  DynFunc = proc (x: int,argv:varargs[string],envp:varargs[string]):int {.nimcall.}


proc main(argv:varargs[string],envp:varargs[string]): int =
    if(argv.len<2):
        raiseOSError(osLastError(), "USAGE: "& $argv[0] & " PROGRAM\nWhere PROGRAM is the user's program to supervise\n")
        # exit?
    var handle:LibHandle = loadLib(argv[1])
    var umain: DynFunc = cast[DynFunc]( checkedSymAddr(handle, "main") )
    return umain(argv.len,argv,envp)
