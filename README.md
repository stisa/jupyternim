

References
----------

[Jupyter Kernel Docs](https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernels)  
[IHaskell](http://andrew.gibiansky.com/blog/ipython/ipython-kernels)  
[Messaging Docs](https://jupyter-client.readthedocs.io/en/latest/messaging.html)  
[Async logger in nim](https://hookrace.net/blog/writing-an-async-logger-in-nim/)  

# nimkernel
Handles init, start, stop of the various loops. 

# messaging
Handles message specifications exposing low level procs to send, receive, decode, encode messages

# sockets
Defines sockets types , how they are created, how their loops work, how they send and receive messages

Once messaging works, we can look at running code etc.

Notes
-----

Running: 
- compile the kernel binary: `nim c --threads:on nimkernel.nim`
- in [nim-spec/kernel.json](https://github.com/stisa/jupyter-nim-kernel/blob/nim-based/nim-spec/kernel.json)
`"C:\\<bla>\\nimkernel"` to the path of `nimkernel` executable
- add spec to jupyter : `jupyter-kernelspec install nim-spec`
- run `jupyter-notebook` and select `new>nimBsed` 


ZeroMQ is dinamically linked, so it need to be installed and added to path  
Messages must be multipart
signature must be lowercase