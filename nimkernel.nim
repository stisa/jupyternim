#import private/sockets,private/utility
import private/messages
import os

#let programName = paramStr(0)
let arguments = commandLineParams() # [0] should always be the connection file

#echo programName
assert(arguments.len >= 1, "Something wrong, no arguments passed to nimkernel??")
# assert that arguments[0] is a json file, maybe slice [^4,end]==json

var connectionmsg = arguments[0].parseConnMsg
  
echo $connectionmsg

#[type Kernel = object
    hb: Heartbeat
    exiting:bool



proc shutdown(k:var Kernel)=
    k.exiting = true
    #ioloop.IOLoop.instance().stop() TODO

# TODO on separate thread?
proc hbloop(k: var Kernel) =
    dprint(2, "Starting loop for 'Heartbeat'...")
    while k.hb.beat() :
        discard # should wait?
    
    # if we exit the beat loop, start exiting
    dprint(2, "Exiting loop for 'Heartbeat',shutdown...")    
    k.shutdown()

proc run_thread(loop:proc(),name:string) =
    dprint(2, "Starting loop for '%s'..." % name)
    while loop.running :
        dprint(2, "%s Loop!" % name)
        try:
            loop.turn() # exec a single time
        except ZMQError as e:
            dprint(2, "%s ZMQError!" % name)
            if e.errno == errno.EINTR:
                continue
            else:
                raise
        except Exception:
            dprint(2, "%s Exception!" % name)
            if exiting:
                break
            else:
                raise
        else:
            dprint(2, "%s Break!" % name)
            break]#