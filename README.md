# Minimal Nim kernel for Jupyter

This is a rough adaptation of https://github.com/brendan-rius/jupyter-c-kernel .
It's mostly functional, there are probably bugs lurking around.

**NOTE**: Variables are **NOT** shared between blocks !! I'll try working on it when I have time

## Prereqs
- a working `nim` installation ( [download](http://nim-lang.org/download.html) )
- a working `jupyter` (and  **python 3^**) installation ( I recomend [miniconda3](http://conda.pydata.org/miniconda.html)   
and adding jupyter with `conda install jupyter` )

## Install
 
- `git clone https://github.com/stisa/jupyter-nim-kernel.git`
- `cd jupyter-nim-kernel`
- `pip install -e .`
- `jupyter-kernelspec install nim_spec/`
- `jupyter-notebook`.

## Note
Forked from https://github.com/brendan-rius/jupyter-c-kernel and adapted to work 
with [nim](nim-lang.org).  

This a simple proof of concept. It's not intended to be used in production in its current shape.   

## License

[MIT](LICENSE.txt)

