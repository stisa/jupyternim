Jupyter Nim
====

This is an experimental nim version of a kernel for [jupyter notebooks](http://jupyter.org/). 

~~Experimental plotting is available using the magic `#>inlineplot width height`, e.g. `#>inlineplot 640 480`  through
a simple wrapper around `matplotlib` provided [here](jupyternimpkg/pyplot.nim). **Only python 3 is supported.**~~
  
Look at [example-notebook](examples/example-notebook.ipynb) for some examples.  

NOTE: running a notebook with this creates a directory `~/.jupyternim` in which it stores blocks of code, pngs, compiled outputs, etc.

Prereqs
-------
- a working `nim` installation ( [download](http://nim-lang.org/download.html) )
- a working `jupyter` installation ( I recomend [miniconda3](http://conda.pydata.org/miniconda.html) and adding jupyter with `conda install jupyter` )
- a `zeromq` installation. Currently tested only with [ZeroMQ](http://zeromq.org/intro:get-the-software) 4.2. **It must be in PATH or the kernel won't run**.

Installation 
------------
TL,DR: two commands:
```
nimble install https://github.com/stisa/jupyternim
jupyternim
```
Done!

### Long version:

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

### HotCodeReloading
To enable the **very** experimental hotcodereloading support, you'll need to recompile `jupyternim` with `-d:useHcr` and then overwrite the one in `~/.nimble/pkgs/jupyternim-<version>` with it.  
The hotcodereloading mostly works, but there are various bugs that prevent its use. For examples, printing a float crashes it.

Magics:
-------

**passing flags**

`#>flags < --some > < --d:flag >`
Pass flags to nim compiler, default is `--verbosity:0 -d:release`.  
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
TODO: provide a way to override default compilation output file

**delete old temp files**
`#>clear all`

**displaying an image**
To display a PNG image, simply echo its base64 encode delimited by `#>jnps0000x0000` and `jnps<#` where `0000x0000` is the display resolution.
An example of how to implement this can be seen [in graph](https://github.com/stisa/graph/blob/master/src/graph.nim#L16)

For example, using that:

```nim
import graph, graph/draw
from graph/funcs import exp
let xx = linspace(0.0,10,1)
var srf = plotXY(xx,exp(xx),Red,White)
echo srf.jupyterPlotData
echo 
```


State:
------
- Compiles and runs code.
- Compiler output and results are shown.
- Basic image handling
- all code is re run on each cell added, but only output of the last cell is shown
- hotcodereloading works well for simple code, but crashes with even slightly involved code, eg printing a float.

TODO
----
- Finish implementing messaging ( completion, introspection, history, display... )
- Connect to nimsuggest via socket, parse its output for introspection requests
- Documentation lookup magic? eg. put docs in a subfolder, then `#>doc sequtils` opens a browser to the correct `.html` page ( possibly local )  
- Magics to reduce verbosity, ~~pass flags to compiler~~
- Use nim plotly/ggplot/other nim plotting lib
- improve hotcodereloading (probably needs work on the compiler side)

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

Internal Notes
--------------
Messages must be multipart
signature must be lowercase
http://nim-lang.org/docs/tinyc.html
