
type Kernel = object
    hb: Heartbeat
    exiting:bool

proc shutdown(k:var Kernel)=
    k.exiting = true
    #ioloop.IOLoop.instance().stop()

# TODO on separate thread
proc hbloop(k: var Kernel) =
    while k.hb.beat :
        discard
    # if we exit the beat loop, start exiting
    k.shutdown

def run_thread(loop, name):
    dprint(2, "Starting loop for '%s'..." % name)
    while not exiting:
        dprint(2, "%s Loop!" % name)
        try:
            loop.start()
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
            break

def heartbeat_loop():
    dprint(2, "Starting loop for 'Heartbeat'...")
    while not exiting:
        dprint(3, ".", end="")
        try:
            zmq.device(zmq.FORWARDER, heartbeat_socket, heartbeat_socket)
        except zmq.ZMQError as e:
            if e.errno == errno.EINTR:
                continue
            else:
                raise
        else:
            break


# Utility functions:
def shutdown():
    global exiting
    exiting = True
    ioloop.IOLoop.instance().stop()
