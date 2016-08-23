import uuid,json,times,hmac,zmq

proc dprint*(level:int,args:string,kwargs:varargs[string])=
    ## Show debug information
    if level > 1:
        var s = "DEBUG: "&args
        for a in kwargs :
            s &= a
        echo s

## Return a new uuid for message id 
proc msg_id():string = uuid.gen()

#def str_to_bytes(s):
#    return s.encode('ascii') if PYTHON3 else bytes(s)

##Sign a message with a secure signature.  
proc sign(msg_list:openarray[string],auth:Authentication):auto = # string?
    var h = auth.copy
    for m in msg_list:
        h.update(m) # ???
    result = h.hexdigest 

proc nowISOstr():string = getDateStr()&'T'&getClockStr()
## make a new header
proc new_header(msg_type:string,engine_id:string): JsonNode =
    result = %* {
            "date": nowISOstr(),
            "msg_id": msg_id(),
            "username": "kernel",
            "session": engine_id,
            "msg_type": msg_type,
            "version": "5.0",
        }

proc send(stream:TConnection, msg_type,engine_id:string,content,parent_header,metadata:JsonNode=nil,identities:seq[string]=nil) =
    var header = new_header(msg_type,engine_id)
    var c = content
    var p = parent_header
    var m = metadata
    if content== nil:
        c = %*"{}"
    if parent_header== nil:
        p = %*"{}"
    if metadata== nil:
        m = %*"{}"
    
    var msg_list = [
        $header,
        $parent_header,
        $metadata,
        $content
    ]

    var sg = msg_list.sign
    var parts:  # TODO : parts type 
    if identities==nil:
        parts = @[DELIM,
             signature,
             msg_lst[0],
             msg_lst[1],
             msg_lst[2],
             msg_lst[3]]
    else:
        parts = @[identities, 
             DELIM,
             signature,
             msg_lst[0],
             msg_lst[1],
             msg_lst[2],
             msg_lst[3]]
    dprint(1, "send parts:", parts)
    stream.send_multipart(parts)
    stream.flush()
