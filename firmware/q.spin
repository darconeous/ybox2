{{
  Generic Multi-Queue System
  Robert Quattlebaum <darco@deepdarc.com>

  NOTE: Not yet stable for multi-threaded use!
}}
CON
  Q_PAGES =      80 ' Must be less than 127
  Q_PAGE_SIZE =  8 ' Must be less than 127
  Q_MAX =        8  ' Must be less than 127
CON
  Q_DESC_BEGIN = 0
  Q_DESC_END =   1
  Q_DESC_INDEX = 2
  Q_DESC_SIZE =  3

  PAGE_FLAG =    %1000_0000

  Q_NIL =        %1000_0001
CON
  ERR_Q_EMPTY       = -1
  ERR_Q_INVALID     = -3
  ERR_OUT_OF_PAGES  = -2
  ERR_OUT_OF_QUEUES = -4
  ERR_RUNTIME       = -10
DAT
q_desc         byte 0[Q_MAX*Q_DESC_SIZE]
q_page         byte 0[Q_PAGES*Q_PAGE_SIZE]
next_free_desc byte 0
next_free_page byte 0
q_count        byte 0
p_count        byte 0
q_lock         long -1
PUB init | i
  if q_lock==-1
    next_free_desc:=0
    repeat i from 0 to Q_MAX-1
      q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]:=i+1
      q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]:=Q_NIL
     
    next_free_page:=0
    repeat i from 0 to Q_PAGES-1
      q_page[i*Q_PAGE_SIZE]:=i+1
     
    if(q_lock := locknew) == -1
      abort FALSE
  return TRUE
PRI lock
  repeat while NOT lockset(q_lock)
PRI unlock
  lockclr(q_lock)
  
PUB new : i | p
  lock
  i:=next_free_desc
  if i=>Q_MAX
    unlock
    abort ERR_OUT_OF_QUEUES
  next_free_desc:=q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]
  q_count++
  unlock
  p:=\newPage
  if p<0
    lock
    next_free_desc:=i
    q_count--
    unlock
    abort p
  q_desc[i*Q_DESC_SIZE+Q_DESC_END]:=p
  q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]:=p
  q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]:=0

PUB purge(i) | next_page,old_page
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  ' Runtime sanity check. Can be removed once the Q object is stable.
  if q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]==Q_NIL OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]=>constant(Q_PAGE_SIZE-1)
    abort ERR_RUNTIME
    
  next_page := q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]

  repeat while next_page <> Q_NIL
    old_page := next_page
    if old_page <> q_desc[i*Q_DESC_SIZE+Q_DESC_END]
      next_page:=pageToIndex(q_page[old_page*Q_PAGE_SIZE])
    else
      next_page:=Q_NIL
    freePage(old_page)

  q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]:=Q_NIL
  q_desc[i*Q_DESC_SIZE+Q_DESC_END]:=Q_NIL
  q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]:=Q_NIL
   
PUB delete(i) | old_page

  purge(i)
  
  lock

  ' Insert Queue back into pool
  q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]:=next_free_desc
  q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]:=Q_NIL
  next_free_desc:=i

  q_count--
  unlock
    
PUB push(i,b) | p
  if i<0 OR i=>Q_MAX
    abort ERR_Q_INVALID

  p:=q_desc[i*Q_DESC_SIZE+Q_DESC_END]

  ' Runtime sanity check. Can be removed once the Q object is stable.
  if p==Q_NIL OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]==Q_NIL OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]=>constant(Q_PAGE_SIZE-1)
    abort ERR_RUNTIME

  q_page[p*Q_PAGE_SIZE+1+q_page[p*Q_PAGE_SIZE]]:=b

  if q_page[p*Q_PAGE_SIZE]=>constant(Q_PAGE_SIZE-2)
    ' Need to allocate a new page
    p:=newPage
    q_desc[i*Q_DESC_SIZE+Q_DESC_END]:=p
    q_page[(q_desc[i*Q_DESC_SIZE+Q_DESC_END])*Q_PAGE_SIZE]:=indexToPage(p)
  else
    q_page[p*Q_PAGE_SIZE]++

  return 0
       
PUB pull(i) : val | p
  p:=q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]

  ' Runtime sanity check. Can be removed once the Q object is stable.
  if p==Q_NIL OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]==Q_NIL OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]=>constant(Q_PAGE_SIZE-1)
    abort ERR_RUNTIME
  
  if p==Q_NIL OR NOT q_page[p*Q_PAGE_SIZE] OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX] == q_page[p*Q_PAGE_SIZE]
    abort ERR_Q_EMPTY

  val := q_page[p*Q_PAGE_SIZE+1+q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]]

  if q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]+1 => constant(Q_PAGE_SIZE-1)
    ' This page is empty.
    ifnot isPage(q_page[p*Q_PAGE_SIZE])
      abort -60
    ' Move to the next page
    q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]:=pageToIndex(q_page[p*Q_PAGE_SIZE])
    q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]:=0
    ' Free this page
    freePage(p)
  else
    q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX]++
    
PUB pushData(i,ptr,len)
  repeat while len--
    repeat while \push(i,byte[ptr]) <> 0
    ptr++  
PUB isEmpty(i) | p
  if i<0 OR i=>Q_MAX
    return TRUE
  p:=q_desc[i*Q_DESC_SIZE+Q_DESC_BEGIN]
  return p==Q_NIL OR NOT q_page[p*Q_PAGE_SIZE] OR q_desc[i*Q_DESC_SIZE+Q_DESC_INDEX] == q_page[p*Q_PAGE_SIZE]

PRI newPage : i
  lock
  if p_count=>Q_PAGES-1
    unlock
    abort ERR_OUT_OF_PAGES
  if next_free_page=>Q_PAGES
    unlock
    abort -50
  i := next_free_page
  next_free_page:=q_page[i*Q_PAGE_SIZE]
  q_page[i*Q_PAGE_SIZE]:=0
  p_count++
  unlock
PRI freePage(i)
  if i<0 OR i=>Q_PAGES
    abort ERR_RUNTIME
  lock
  q_page[i*Q_PAGE_SIZE]:=next_free_page
  next_free_page:=i
  p_count--
  unlock
PUB pagesUsed
  return p_count  
PRI isPage(x)
  return x & PAGE_FLAG
PRI pageToIndex(x)
  return x & !PAGE_FLAG
PRI indexToPage(x)
  return x | PAGE_FLAG