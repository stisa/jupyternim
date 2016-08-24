

References
----------

[Jupyter Kernel Docs](https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernels)  
[IHaskell](http://andrew.gibiansky.com/blog/ipython/ipython-kernels)  
[Messaging Docs](https://jupyter-client.readthedocs.io/en/latest/messaging.html)  


ZeroMQ is dinamically linked, so it need to be installed and added to path  

https://hookrace.net/blog/writing-an-async-logger-in-nim/  

The Plan
--------

# nimkernel
Handles init, start, stop of the various loops. 
# messaging
Handles message specifications exposing low level procs like send, receive, decode, encode
# sockets
Defines sockets types , how they are created, how their loops work

Once messaging works, we can look at running code etc.

NOtes
-----

Messages must be multipart

signature must be lowercase