import python3 #TODO python2

from os import splitfile,changeFileExt
#[
================   ===============================
character          description
================   ===============================
  r                Red
  b                Blue
  g                Green
  c                Cyan
  m                Magenta
  y                Yellow
  k                Black
  w                White
===================================================
  -                solid line style
  --               dashed line style
  -.               dash-dot line style
  :                dotted line style
===================================================
  .                point marker
  ,                pixel marker
  o                circle marker
  v                triangle_down marker
  ^                triangle_up marker
  <                triangle_left marker
  >                triangle_right marker
  1                tri_down marker
  2                tri_up marker
  3                tri_left marker
  4                tri_right marker
  s                square marker
  p                pentagon marker
  *                star marker
  h                hexagon1 marker
  H                hexagon2 marker
  +                plus marker
  x                x marker
  D                diamond marker
  d                thin_diamond marker
  |                vline marker
  _                hline marker
================    ===============================
]#
proc initPlot*()= 
  initialize()
  discard runSimpleString("import matplotlib\nmatplotlib.use('pdf')\nfrom matplotlib import pyplot as pp\n") # load pyplo
proc `$`[T](a:openarray[T]):string =
  result = "["
  for e in 0..<a.len-1:
    result.add($a[e]&',')
  result.add($a[^1]&"]")

template endPlot*():untyped= 
  let pngname = instantiationInfo(0).filename
  discard runSimpleString("pp.savefig(\"inimtemp/"&pngname.changeFileExt(".png")&"\")")
  finalize()

proc plot*[T](x,y:openarray[T],lncolor:string="r",lnstyle:string="-",lnmarker:string="",label:string="")=
 # assert(lnstyle in {'-', "--", "-.", ':'})
  const markers = [" ","",".", ",", "o", "v", "^", "<", ">", "1", "2", "3", "4", "s", "p", "*", "h", "H", "+", "x", "D", "d", "|", "_"]
  const styles =  [" ","","-","--","-.",":"]
  const colors = ["r","b","g","c","m","y","k","w"]
  assert(lnmarker in markers)
  assert(lncolor in colors)
  assert(lnstyle in styles)    
  if label!="":
    discard runSimpleString("pp.plot("& $x & "," & $y & "," & "color='"&lncolor&"',"& "linestyle='"&lnstyle&"',"& "marker='"&lnmarker&"', label='"&label&"')")
  else:
    discard runSimpleString("pp.plot("& $x & "," & $y & "," & "color='"&lncolor&"',"& "linestyle='"&lnstyle&"',"& "marker='"&lnmarker&"')")

proc xlabel*(lb:string):int {.discardable} = runSimpleString("pp.xlabel('"&lb&"')")
proc ylabel*(lb:string):int {.discardable} = runSimpleString("pp.ylabel('"&lb&"')")
proc title*(t:string):int {.discardable} = runSimpleString("pp.title('"&t&"')")
proc legend*():int {.discardable} = runSimpleString("pp.legend()")

template show*(body:untyped):untyped=
  from os import changeFileExt
  initPlot()
  body
  endPlot()

when isMainModule:
  show:  
    plot(@[0.0,0.5,1],@[0.0,1,2],"b","--","o","dots")
    xlabel("dotssss")
    legend()
    plot(@[0.0,0.2,0.8],@[0.0,1,2],"r","-","o","dotsline")
