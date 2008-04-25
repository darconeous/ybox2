obj
  tcp : "driver_socket"
pub getFieldFromQuery(packeddataptr,keystring,outvalue,outsize) | i,char
  i:=0
  repeat while BYTE[packeddataptr]
    if BYTE[packeddataptr]=="=" 'AND strsize(keystring)==i
      packeddataptr++
      i:=0
      repeat while byte[packeddataptr] AND byte[packeddataptr]<>"&" AND i<outsize-2
         BYTE[outvalue][i++]:=byte[packeddataptr++]
      BYTE[outvalue][i]:=0
      unescapeURLInPlace(outvalue)
      return i
    if BYTE[packeddataptr] <> BYTE[keystring][i]
      ' skip to &
      repeat while byte[packeddataptr] AND byte[packeddataptr]<>"&"
        packeddataptr++
      ifnot byte[packeddataptr] 
        quit
      packeddataptr++
      i:=0
    else
      packeddataptr++
      i++  
  return 0

pub unescapeURLInPlace(in_ptr) | out_ptr,char,val
  out_ptr:=in_ptr
  repeat while (char:=byte[in_ptr++])
    if char=="-"
      ' Convert dashes to spaces for historical reasons
      char:=" "
    if char=="%"
      case (char:=byte[in_ptr++])
        "a".."f": val:=char-"a"+10
        "A".."F": val:=char-"A"+10
        "0".."9": val:=char-"0"
        0: quit
        other: next
      val:=val<<4
      case (char:=byte[in_ptr++])
        "a".."f": val|=char-"a"+10
        "A".."F": val|=char-"A"+10
        "0".."9": val|=char-"0"
        0: quit
        other: next
      char:=val
    byte[out_ptr++]:=char
  byte[out_ptr++]:=0
  return TRUE
pub getNextHeader(handle,namePtr,nameLen,valuePtr,valueLen) | count,char
  count:=0
  valueLen--
  nameLen--
  repeat while not tcp.isEOF(handle)
    char:=tcp.readByte(handle)
    case char
      13:
        tcp.readByte(handle)
        return count
      10,-1:
        return count
      ":":
        tcp.readByte(handle)
        count++
        byte[namePtr]:=0
        quit
      other:
        count++
        if nameLen
          nameLen--
          byte[namePtr++]:=char
  repeat while not tcp.isEOF(handle)
    char:=tcp.readByte(handle)
    case char
      13,10,-1:
        byte[valuePtr]:=0
        tcp.readByte(handle)
        return count
      other:
        count++
        if valueLen
          valueLen--
          byte[valuePtr++]:=char
  byte[namePtr]:=0
  byte[valuePtr]:=0
pub parseRequest(handle,method,path,query) | i,char
    i:=0
    repeat while ((char:=tcp.readByte(handle)) <> -1) AND (NOT tcp.isEOF(handle)) AND i<7
      BYTE[method][i]:=char
      if char == " "
        quit
      i++
    BYTE[method][i]:=0
    i:=0
    repeat while ((char:=tcp.readByte(handle)) <> -1) AND (NOT tcp.isEOF(handle)) AND i<63
      BYTE[path][i]:=char
      if char == " " OR char == "?"  OR char == "#"
        quit
      i++

    if BYTE[path][i]=="?"
      ' If we stopped on a question mark, then grab the query
      BYTE[path][i]:=0
      i:=0
      repeat while ((char:=tcp.readByte(handle)) <> -1) AND (NOT tcp.isEOF(handle)) AND i<63
        BYTE[query][i]:=char
        if char == " " OR char == "#" OR char == 13
          quit
        i++        
      BYTE[query][i]:=0
    else
      BYTE[path][i]:=0
      BYTE[query][0]:=0
         