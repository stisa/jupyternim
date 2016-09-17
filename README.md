INim
-----

This is an experimental nim-only ( well apart from zmq ) version, reimplementing all machinery ( messaging, sockets, execution... ).
There's a version using python here: [jupyter-nim-kernel](https://github.com/stisa/jupyter-nim-kernel).
I'm going to port features from there to here ( as time permits ).
Experimental plotting is available using the magic `#>inlineplot width height`, e.g. `#>inlineplot 640 480`
The plotting lib used is [graph](https://github.com/stisa/graph). Other plotting libs may be considered, and as always, PRs are welcome!

Running: 
---------
- compile the kernel binary: `nim c --threads:on nimkernel.nim`
- in [nim-spec/kernel.json](https://github.com/stisa/jupyter-nim-kernel/blob/nim-based/nim-spec/kernel.json) change 
`"C:\\<blah>\\nimkernel"` to the path of `nimkernel` executable
- add spec to jupyter : `jupyter-kernelspec install nim-spec`
- run `jupyter-notebook` and select `new>nim - pure` 

As an alternative, in [nim-spec/kernel.json](https://github.com/stisa/jupyter-nim-kernel/blob/nim-based/nim-spec/kernel.json) change 
`"C:\\<blah>\\nimkernel"` to the **full** path of `nimkernel` executable and then run `nimble setup`

Note that ZeroMQ is dinamically linked, so it needs to be installed and added to path  

State:
------
- Compiles and runs code.
- Compiler output and results are shown.
- Basic 2d plotting  
- **Still no shared context**.

TODO
----
- Shared context. This is currently top/near-top priority. Any help is appreciated. **HARD**
- Finish implementing messaging ( completion, introspection, history, display... )
- Make this a nimble package, that automatically installs the kernel. **MEDIUM**, needs patching nimble?
- Handle shutdown gracefully
- Connect to nimsuggest via socket, parse its output for introspection requests

References
----------

[Jupyter Kernel Docs](https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernels)  
[IHaskell](http://andrew.gibiansky.com/blog/ipython/ipython-kernels)  
[Messaging Docs](https://jupyter-client.readthedocs.io/en/latest/messaging.html)  
[Async logger in nim](https://hookrace.net/blog/writing-an-async-logger-in-nim/)  

General structure
-----------------

### nimkernel
Handles init, start, stop of the various loops. 

### messaging
Handles message specifications exposing low level procs to send, receive, decode, encode messages

### sockets
Defines sockets types , how they are created, how their loops work, how they send and receive messages


Internal Notes
--------------
Messages must be multipart
signature must be lowercase