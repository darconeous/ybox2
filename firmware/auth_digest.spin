{{
  MD5-Digest HTTP authentication object
  By Robert Quattlebaum <darco@deepdarc.com>

  Work in progress. Doesn't work yet.
}}
obj
  settings : "settings"
  base64 : "base64"
  base16 : "base16"
  hasher : "md5"
CON
  STAT_UNAUTH =  FALSE
  STAT_STALE =   $80
  STAT_AUTH =    TRUE

  NONCE_LENGTH = 8 'In bytes
DAT
type byte "Digest",0
realm byte "ybox2",0

hash_value    long 0[hasher#HASH_LENGTH]
hash_buffer   byte 0[hasher#BLOCK_LENGTH]
hash_size     long 0

pri hash_init
  hasher.hashStart(@hash_value)
  hash_buffer_size:=0
pri hash_append(ptr,len)
pri hash_finish(ptr,len)
'  hasher.hashFinish(dataptr,datalen,totallen,h)

pri generateNonce(ptr)
  bytefill(ptr,0,NONCE_LENGTH)
pri isValidNonce(ptr)
  return TRUE
pri getFieldWithKey(packeddataptr,keystring) | i,char
  i:=0
  repeat while BYTE[packeddataptr]
    if BYTE[packeddataptr]=="=" AND strsize(keystring)==i
      packeddataptr++
      if BYTE[packeddataptr]==34 ' if it is a quote
        packeddataptr++
      return packeddataptr
    if BYTE[packeddataptr] <> BYTE[keystring][i]
      ' skip to ,
      repeat while byte[packeddataptr] AND byte[packeddataptr]<>","
        packeddataptr++
      ifnot byte[packeddataptr] 
        quit
      packeddataptr++
      ' skip past whitespace
      repeat while byte[packeddataptr] AND byte[packeddataptr]==" "
        packeddataptr++
      i:=0
    else
      packeddataptr++
      i++  
  return 0

pub authenticateResponse(str,method,uriPath) | i,H1[hasher#HASH_LENGTH/4],H2[hasher#HASH_LENGTH/4],response[hasher#HASH_LENGTH/4],nonce[NONCE_LENGTH/4],buffer[20]
  ' Skip past the word "Digest"
  repeat i from 0 to 5
    if byte[str][i]<>type[i]
      return STAT_UNAUTH
  str+=i+1

  base16.decode(@nonce,getFieldWithKey(str,string("nonce")),NONCE_LENGTH)

  ifnot isValidNonce(@nonce)
    return STAT_STALE
    
  'base16.decode(@response,getFieldWithKey(str,string("response")),hasher#HASH_LENGTH)
  
  
  return STAT_UNAUTH
     
pub generateChallenge(dest,len,authstate)|nonce[NONCE_LENGTH/4]
  bytemove(dest,type,strlen(type))
  len-=strlen(type)
  dest+=strlen(type)
  byte[dest++][0]:=" "
  len--
  bytemove(dest,string("realm=",34),7)
  dest+=7
  len-=7
  bytemove(dest,realm,strlen(realm))
  len-=strlen(realm)
  dest+=strlen(realm)

  bytemove(dest,string(34,", nonce=",34),10)
  dest+=10
  len-=10
  base16.encode(dest,@nonce,len)
  dest+=NONCE_LENGTH/2
  len-=NONCE_LENGTH/2
  
  byte[dest++][0]:=" "
  len--

  byte[dest++][0]:=0
  
  return 0

pub setAdminPassword(str)
  settings.setString(settings#MISC_PASSWORD,str)
  settings.commit
         