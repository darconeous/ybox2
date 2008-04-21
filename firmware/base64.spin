{{
** Base64 decoding/encoding functions
** by Robert Quattlebaum <darco@deepdarc.com>
** 2008-04-18
**
** TODO: Implement this in ASM!
** TODO: Implement encoder!    
}}
PUB inplaceDecode(in_ptr) | out_ptr,i,in,char,size
{{ Decodes a base64 encoded string in-place. Returns the size of the decoded data. }}
  out_ptr:=in_ptr
  size:=0
  repeat
    ifnot BYTE[in_ptr]
      quit
    repeat i from 0 to 3
      char:=BYTE[in_ptr++]
      'repeat while (char:=BYTE[in_ptr++])==" "
      ifnot char
        BYTE[@in][i]:="="
        in_ptr--
        quit
      else
        BYTE[@in][i]:=char
     
    i:=base64_decode_4(@in,out_ptr)
    out_ptr+=i
    size+=i
  while char AND i==3     
  BYTE[out_ptr]:=0
  return size

pri base64_tlu(char) | i
  case char
    "A".."Z": return char-"A"
    "a".."z": return char-"a"+26
    "0".."9": return char-"0"+52
    "+": return 62
    "/": return 63
    other: return 0
PRI base64_decode_4(inptr,outptr) | retVal,i,out
  out:=0
  retVal:=3
  repeat i from 0 to 3
    if(BYTE[inptr][i]=="=")
      case i
        3: retVal:=2
        2: retVal:=1
        1: retVal:=0
        0: retVal:=0
      quit
    out|=\base64_tlu(BYTE[inptr][i])<<((3-i)*6)
  if retVal
    repeat i from 0 to retVal-1
      BYTE[outptr][i]:=BYTE[@out][2-i]
  return retVal

