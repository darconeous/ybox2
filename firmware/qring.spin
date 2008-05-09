{{ Ring buffer
** A more simple version of q.spin with the same API.
}}
CON
  Q_MAX = 4
  Q_SIZE = 1024
  buffer_mask   = Q_SIZE - 1
CON
  ERR_Q_EMPTY       = -5
  ERR_Q_INVALID     = -3
  ERR_OUT_OF_PAGES  = -2
  ERR_OUT_OF_QUEUES = -4
  ERR_RUNTIME       = -10

DAT
  buffer byte 255[Q_MAX*Q_SIZE+1]
  writepoint  word 0[Q_MAX]
  readpoint    word 0[Q_MAX]
  
  q_next byte 0
  q_lock long -1
PUB init | i
  if q_lock==-1
    q_next:=0
    repeat i from 0 to Q_MAX-1
      buffer[i*Q_SIZE]:=i+1     
    if(q_lock := locknew) == -1
      abort FALSE
  return TRUE
PRI lock
  repeat while NOT lockset(q_lock)
PRI unlock
  lockclr(q_lock)
  
PUB new : i | p
  lock
  i:=q_next
  if i=>Q_MAX
    unlock
    abort ERR_OUT_OF_QUEUES
  q_next:=buffer[i*Q_SIZE]
  writepoint[i]:=0
  readpoint[i]:=0
  i++
  unlock
  

PUB purge(i) | next_page,old_page
  i--
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID
  readpoint[i]:=writepoint[i]
   
PUB delete(i) | old_page

  purge(i)
  i--
  
  lock

  ' Insert Queue back into pool
  buffer[i*Q_SIZE]:=q_next
  q_next:=i

  unlock
PUB bytesFree(i)
  i--
  if i<0 OR i=>Q_MAX
    return 0
  return buffer_mask-((writepoint[i]-readpoint[i])&buffer_mask)
    
PUB push(i,b) | p
  i--
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  if (readpoint[i]<> (writepoint[i] + 1) & buffer_mask)
    buffer[i*Q_SIZE+writepoint[i]+1]:=b
    writepoint[i] := (writepoint[i] + 1) & buffer_mask
  else   
    abort -1

  return 1
       
PUB pull(i) : val | p
  i--
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  if (readpoint[i]<>writepoint[i])
    val := buffer[i*Q_SIZE+readpoint[i]+1]
    readpoint[i] := (readpoint[i] + 1) & buffer_mask
  else
    abort ERR_Q_EMPTY
    
PUB pushData(i,ptr,len)
  if bytesFree(i)<len
    abort -1
  repeat while len--
    push(i,byte[ptr])
    ptr++
  return 1  
PUB isEmpty(i)
  ifnot i
    return TRUE
  i--
  return readpoint[i]==writepoint[i]

