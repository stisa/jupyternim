import strutils,json

type ConnectionMsg* = object
    ip*: string
    signature_scheme*: string
    key*: string
    hb_port*,iopub_port*,shell_port*,stdin_port*,control_port*: BiggestInt
    kernel_name*: string

proc parseConnMsg*(connfile:string):ConnectionMsg =
    var connectionfile = connfile.readFile
    var parsedconn = parseJson(connectionfile)
    result.ip = parsedconn["ip"].str
    result.signature_scheme = parsedconn["signature_scheme"].str
    result.key = parsedconn["key"].str
    result.hb_port = parsedconn["hb_port"].num
    result.iopub_port = parsedconn["iopub_port"].num
    result.shell_port = parsedconn["shell_port"].num
    result.stdin_port = parsedconn["stdin_port"].num
    result.control_port = parsedconn["control_port"].num
    result.kernel_name = parsedconn["kernel_name"].str

proc `$`*(cm:ConnectionMsg):string=
    result = "ip: "& cm.ip &
             "\nsignature_scheme: "&cm.signature_scheme&
             "\nkey: "&cm.key&
             "\nhb_port: " & $cm.hb_port&
             "\niopub_port: "& $cm.iopub_port&
             "\nshell_port: "& $cm.shell_port&
             "\nstdin_port: "& $cm.stdin_port&
             "\ncontrol_port: "& $cm.control_port&
             "\nkernel_name: "&cm.kernel_name

type WireMsg = object
    header,parent_header,metadata,content : string
    signature : string

proc deserialize*(msg:string) =#: tuple[ id:string, m: JsonNode] =
    #let delim_ind = msg.find()
    var splitted = msg.split("<IDS|MSG>")
   # var identities = splitted[0]
   # var m_signature = splitted[1].split("\n") 
    #var m_frames = splitted[1][1..high(splitted[1])]
    #var m : JsonNode
    echo "splited"
    echo splitted
    echo "ident"
   # echo identities
    echo "newlnied"
  #  echo m_signature
    echo "endmes"
  #[]  m["header"]        = %* m_frames[0]
    m["parent_header"] = %* m_frames[1]
    m["metadata"]      = %* m_frames[2]
    m["content"]       = %* m_frames[3]
    #check_sig = sign(m_frames)
    #if check_sig != m_signature:
     #   raise ValueError("Signatures do not match")
]#
  #  result = (identities, m)
    #echo msg