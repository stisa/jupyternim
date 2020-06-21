Jupyter Nim
====

This is an experimental nim version of a kernel for [jupyter notebooks](http://jupyter.org/). 

Experimental plotting is available using the magic `#>inlineplot width height`, e.g. `#>inlineplot 640 480`  through
a simple wrapper around `matplotlib` provided [here](jupyternimpkg/pyplot.nim). **Only python 3 is supported.**
  
Look at [example-notebook](examples/example-notebook.ipynb) for some examples.  

NOTE: running a notebook with this creates a directory `inimtemp` in which it stores blocks of code, pngs, compiled outputs, etc.

Prereqs
-------
- a working `nim` installation ( [download](http://nim-lang.org/download.html) )
- a working `jupyter` installation ( I recomend [miniconda3](http://conda.pydata.org/miniconda.html) and adding jupyter with `conda install jupyter` )
- a `zeromq` installation. Currently tested only with [ZeroMQ](http://zeromq.org/intro:get-the-software) 4.2. **It must be in PATH or the kernel won't run**.
- a `matplotlib` installation, only if you want to use the basic wrapper provided [here](jupyternim/pyplot.nim) ( with anaconda, just `conda install matplotlib` and you're set )

Installation 
------------
The kernel should be automatically compiled by doing `nimble install jupyternim` ( or `nimble install https://github.com/stisa/jupyternim` if it's not in nimble yet).
  
Now you need to run `jupyternim` to register the kernel with jupyter (you can run `jupyternim` directly if you have `.nimble/bin` in your path, or run it from
`<nimblepath>/pkgs/jupyternim-####`). 


Alternatively, try the following:

- clone this repo: `git clone https://github.com/stisa/jupyternim`
- then go into the cloned dir `cd jupyternim`
- register to nimble with `nimble install`
- compile with `nimble build`
- run `jupyternim`to register the kernel
- run `jupyter notebook`

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
Enable plotting. This uses a simplified wrapper around matplotlib, see [pyplot](src/jupyternimpkg/pyplot.nim)
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
- ~~Handle shutdown gracefully Done?~~
- Connect to nimsuggest via socket, parse its output for introspection requests
- Documentation lookup magic? eg. put docs in a subfolder, then `#>doc sequtils` opens a browser to the correct `.html` page ( possibly local )  
- Magics to reduce verbosity, ~~pass flags to compiler~~
- Move plot setup outside `handleExecute`
- ~~Do we want to distribute libzmq? No~~
- Why does pyplot sigsegv ?
- Use nim plotly/ggplot/other nim plotting lib
- explore hotcodereloading

References
----------

[Jupyter Kernel Docs](https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernels)  
[IHaskell](http://andrew.gibiansky.com/blog/ipython/ipython-kernels)  
[Messaging Docs](https://jupyter-client.readthedocs.io/en/latest/messaging.html)  
[Async logger in nim](https://hookrace.net/blog/writing-an-async-logger-in-nim/)  

General structure
-----------------

### jupyternim
Handles init, start, stop of the various loops. 

### messages
Handles message specifications exposing low level procs to decode, encode messages

### sockets
Defines sockets types , how they are created, how their loops work, how they send and receive messages

### jupyternimpkg/pyplot
A basic wrapper around matplotlib, 2d plot, labels, title are in.
Example:
```nim
import jupyternimpkg/pyplot

show: # a template used to init and close the python interpreter for plotting
  plot([0.0,1,2],[0.0,1,2],"r","--","o","y=x") # Show a y=x line, red ("r"), dashed ("--"), with circle markers ("o"), and name "y=x".
  xlabel("X Axis) # Add a label on the xaxis
  legend() # show the legend, in this case y=x
```

Internal Notes
--------------
Messages must be multipart
signature must be lowercase
http://nim-lang.org/docs/tinyc.html
