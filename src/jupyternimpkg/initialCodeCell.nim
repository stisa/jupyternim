import macros 
macro hoist(code)=
  code.expectKind(nnkStmtList)
  result = newStmtList()
  var procBody = newStmtList()
  for st in code:
    case st.kind:
    of  RoutineNodes, nnkVarSection, nnkLetSection, nnkConstSection, 
        nnkTypeSection, nnkImportStmt, nnkExportStmt, nnkImportExceptStmt,
        nnkFromStmt:
      result.add(st)
    else:
      procBody.add(st)
  
  result.add(newProc(postfix(ident("runNewJupyterCellCode"),"*"),
                    body = procBody))
