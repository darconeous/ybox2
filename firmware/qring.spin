{{ Ring buffer
** A more simple version of q.spin with the same API.
}}
CON
  Q_MAX = 4
  Q_SIZE = 1024
  buffer_mask   = Q_SIZE - 1
CON
  ERR_Q_EMPTY       = -1
  ERR_Q_INVALID     = -3
  ERR_OUT_OF_PAGES  = -2
  ERR_OUT_OF_QUEUES = -4
  ERR_RUNTIME       = -10

DAT
  buffer byte 0[Q_MAX*Q_SIZE]
  writepoint  word 0[Q_MAX]
  readpoint    word 0[Q_MAX]
  
  q_next byte 0
  q_lock byte -1
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
  unlock
  writepoint[i]~
  readpoint[i]~
  

PUB purge(i) | next_page,old_page
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID
  readpoint[i]:=writepoint[i]
   
PUB delete(i) | old_page

  purge(i)
  
  lock

  ' Insert Queue back into pool
  buffer[i*Q_SIZE]:=q_next
  q_next:=i

  unlock
    
PUB push(i,b) | p
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  if (readpoint[i]<> (writepoint[i] + 1) & buffer_mask)
    buffer[i*Q_SIZE+writepoint[i]]:=b
    writepoint[i] := (writepoint[i] + 1) & buffer_mask
  else   
    return -1

  return 1
       
PUB pull(i) : val | p
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  if (readpoint[i]<>writepoint[i])
    val := buffer[i*Q_SIZE+readpoint[i]]
    readpoint[i] := (readpoint[i] + 1) & buffer_mask
  else
    abort ERR_Q_EMPTY
    
PUB pushData(i,ptr,len)
  repeat while len--
    repeat while \push(i,byte[ptr]) <> -1
    ptr++  
PUB isEmpty(i)
  return readpoint[i]==writepoint[i]

