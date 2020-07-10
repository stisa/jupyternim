import strutils, times, random, hmac, nimSHA2, md5

template debug*(str: varargs[string, `$`]) =
  when not defined(release):
    let inst = instantiationinfo()
    echo "[" & $inst.filename & ":" & $inst.line & "] ", str.join(" ")

const validx = ['A', 'B', 'C', 'D', 'E', 'F', 
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
const validy = ['8', '9', '0', 'B']

proc genUUID*(nb, upper: bool = true): string =
  ## Generate a uuid version 4.
  ## If ``nb`` is false, the uuid is compatible with IPython console.
  result = if nb: "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx" else: "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  for c in result.mitems:
    if c == 'y': c = sample(validy)
    elif c == 'x': c = sample(validx)
  if not upper: result = result.toLowerAscii

proc sign*(msg: string, key: string): string =
  ##Sign a message with a secure signature.
  result = hmac.hmac_sha256(key, msg).hex.toLowerAscii

proc getISOstr*(): string = getDateStr()&'T'&getClockStr()
