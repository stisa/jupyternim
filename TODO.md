TODO
-----

- Share context between blocks

Ideas:

Inject a block statement before the code to be executed and a locals 
after it.
Save the values returned by locals to a memfile, passing tuples in the 
format (variablename, locationinmemfile) to the caller ( how? A custom 
message may be the answer, or use a string that starts with something 
nim could'nt parse, like \/ and /\ a the end ).

Mantain a map of variables on the kernel side, then inject it before the
block statement and have it load the value from memfile.

Procs, types, can be copy-pasted before the block statement for now ( 
this has problems as procs won't accept types defined inside the block ).
