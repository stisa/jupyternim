import strutils

type WireMsg = object
    header,parent_header,metadata,content : string
    signature : string

proc deserialize(msg:string) =
    #let delim_ind = msg.find()
    var splitted = msg.split("<IDS|MSG>")
    var identities = splitted[0]
    var m_signature = splitted[1][0] 
    var m_frames = splitted[1][1..high(splitted[1])]

    m.header 