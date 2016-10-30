INim
====

This is an experimental nim-only ( well apart from zmq ) version of a kernel for [jupyter notebooks](http://jupyter.org/), reimplementing all machinery ( messaging, sockets, execution... ).  
There's a version reusing the python machinery here: [jupyter-nim-kernel](https://github.com/stisa/jupyter-nim-kernel).  
I'm going to port features from there to here ( as time permits ).  
Experimental plotting is available using the magic `#>inlineplot width height`, e.g. `#>inlineplot 640 480`  
~~The plotting lib used is [graph](https://github.com/stisa/graph). Other plotting libs may be considered, and as always, PRs are welcome!~~
A simple wrapper around `matplotlib` is provided [here](inim/pyplot.nim). **Only python 3 is supported for now**
  
Look at [example-notebook](https://github.com/stisa/INim/blob/master/examples/example-notebook.ipynb) for some examples.  

NOTE: running a notebook with this creates a directory `inimtemp` in which it stores blocks of code, pngs, compiled outputs, etc.

Prereqs
-------
- a working `nim` installation ( [download](http://nim-lang.org/download.html) )
- a working `jupyter` installation ( I recomend [miniconda3](http://conda.pydata.org/miniconda.html) and adding jupyter with `conda install jupyter` )
- a `zeromq` installation. Currently tested only with [ZeroMQ](http://zeromq.org/intro:get-the-software) 4.0.4 . **It must be in PATH or the kernel won't run**.
- a `matplotlib` installation, only if you want to use the basic wrapper provided [here](inim/pyplot.nim) ( with anaconda, just `conda install matplotlib` and you're set )
- ~~**OPTIONAL** My toy [Graph lib](https://github.com/stisa/graph). I will add it to nimble when I flesh it out more.~~

Running: 
---------
The kernel should be automatically compiled and registered with jupyter just by doing `nimble install inim`

Alternatively, try one of the following:

- clone this repo: `git clone https://github.com/stisa/Inim`
- then go into the cloned dir `cd INim`
- and install with nimble `nimble install`

or

- compile the kernel binary: `nim c --threads:on nimkernel.nim`
- in [nim-spec/kernel.json](https://github.com/stisa/jupyter-nim-kernel/blob/nim-based/nim-spec/kernel.json) change 
`"C:\\<blah>\\nimkernel"` to the path of `nimkernel` executable
- add kernel spec to jupyter : `jupyter-kernelspec install nim-spec --user`
- run `jupyter-notebook` and select `new>Nim` 

Note that [ZeroMQ](http://zeromq.org/intro:get-the-software) is dinamically linked, so it needs to be installed **and added to path**  

Magics:
-------

**passing flags**

`#>flags < --some > < --d:flag >`
Pass flags to nim compiler, default is `--hints:off --verbosity:0 -d:release`.  
Passing new flags overwrites all other previous flags, even default ones.
Example: 
```nim
#>flags -d:test

echo "hi"
when defined test:
  echo "test defined"
else:
  echo "test not defined"
```
Outputs:
```
hi
test defined
```

**inlining a plot**
`#>inlineplot <w> <h>`
Enable plotting. This uses a simplified wrapper around matplotlib, see [pyplot](inim/pyplot.nim)
Example:
```nim
#>inlineplot 320 240
show:
  plot([0.0,1,2],[0.0,1,2],"r","--","o","y=x") # Show a y=x line, red ("r"), dashed ("--"), with circle markers ("o"), and name "y=x".
  xlabel("X Axis) # Add a label on the xaxis
  legend() # show the legend, in this case y=x
```

**delete old temp files**
`#>clear all`

State:
------
- Compiles and runs code.
- Compiler output and results are shown.
- Basic 2d plotting  
- **Context partially shared**.
- **FIXME** code at top level in a block is run in every subsequent block. As a workaround, use `when isMainModule:` to avoid this.

TODO
----
- Properly share context. This is currently top/near-top priority. Any help is appreciated. **HARD**
- Finish implementing messaging ( completion, introspection, history, display... )
- ~~Make this a nimble package, that automatically installs the kernel. **MEDIUM**, needs patching nimble?~~ **DONE?**
- Handle shutdown gracefully
- Connect to nimsuggest via socket, parse its output for introspection requests
- Documentation lookup magic? eg. put docs in a subfolder, then `#>doc sequtils` opens a browser to the correct `.html` page ( possibly local )  
- Magics to reduce verbosity, pass flags to compiler
- Move plot setup outside `handleExecute`
- Do we want to distribute libzmq?
- Why does pyplot sigsegv ?

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

### inim/pyplot
A basic wrapper around matplotlib, 2d plot, labels, title are in.
Example:
```nim
import inim/pyplot

show: # a template used to init and close the python interpreter
  plot([0.0,1,2],[0.0,1,2],"r","--","o","y=x") # Show a y=x line, red ("r"), dashed ("--"), with circle markers ("o"), and name "y=x".
  xlabel("X Axis) # Add a label on the xaxis
  legend() # show the legend, in this case y=x
```
Internal Notes
--------------
Messages must be multipart
signature must be lowercase
http://nim-lang.org/docs/tinyc.html