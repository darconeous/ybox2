{{
        ybox2 - settings object
        http://www.deepdarc.com/ybox2

        This object handles the storage and retreval of variables
        and data which need to persist across power cycles.

        Also allows for some rudamentry cross-object communication.
        It's not terribly fast though, so it should be read-from
        and written-to sparingly.
}} 
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  EEPROMPageSize = 128

  SettingsLockPtr = $6FFF
  SettingsPtr = $7000
  SettingsSize = $800


  NET_MAC_ADDR  = $0100
  NET_IPv4_ADDR = $0101
  NET_IPv4_MASK = $0102
  NET_IPv4_GATE = $0103
  NET_IPv4_DNS  = $0104
  NET_DHCPv4_DISABLE = $0105
  
  SOUND_DISABLE = $0200
  
  MISC_CONFIGURED_FLAG = $0300 

  SERVER_IPv4_ADDR = $0400 
  SERVER_IPv4_PORT = $0401 
  SERVER_PATH = $0402 
  SERVER_HOST = $0403 

OBJ
  eeprom : "Basic_I2C_Driver"
PUB start
  if(byte[SettingsLockPtr] := locknew) == -1
    abort FALSE
  return TRUE
  
PUB stop
  lockret(byte[SettingsLockPtr])
  byte[SettingsLockPtr] := -1
PRI lock
  repeat while NOT lockset(byte[SettingsLockPtr])
PRI unlock
  lockclr(byte[SettingsLockPtr])
PUB commit | addr, i
  lock
  addr := SettingsPtr & %11111111_10000000
  eeprom.Initialize(eeprom#BootPin)
  repeat i from 0 to SettingsSize/EEPROMPageSize
    repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addr)
    if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addr, addr, EEPROMPageSize)
      unlock
      abort FALSE
    addr+=EEPROMPageSize
  unlock

PRI findKey_(key) | iter
  iter := SettingsPtr
  repeat while (iter < SettingsPtr+SettingsSize) AND word[iter] AND word[iter+2]
    if word[iter] == key
      return iter
    iter+=4+((word[iter+2]+1) & !1)
  return 0
PUB findKey(key) | retVal
  lock
  retVal:=findKey_(key)
  unlock
  return retVal
PUB getData(key,ptr,size) | iter
  lock
  iter := findKey_(key)
  if iter
    size#>=word[iter+2]
    bytemove(ptr, iter+4, size)
  else
    size:=0
  unlock
  return size
PUB removeData(key) | iter, nextKey
  lock
  iter := findKey_(key)
  if iter
    nextKey := iter+4+word[iter+2]
    bytemove(iter,nextKey, SettingsSize - (nextKey-SettingsPtr))
  unlock
  return iter
PUB setData(key,ptr,size) | iter
  removeData(key)
  lock
  iter := SettingsPtr
  repeat while (iter < SettingsPtr+SettingsSize) AND word[iter] AND word[iter+2]
    iter+=4+((word[iter+2]+1) & !1)
  if iter+4+size>SettingsPtr+SettingsSize
    unlock
    abort FALSE
  word[iter]:=key
  word[iter+2]:=size
  bytemove(iter+4,ptr,size)
  unlock
  return iter

PUB getString(key,ptr,size) | strlen
  ' Strings must be zero terminated.
  strlen:=getData(key,ptr,size-1)
  byte[strlen]:=0  
  return strlen
  
PUB setString(key,ptr)
  return setData(key,ptr,strsize(ptr))  
  
PUB getLong(key) | retVal
  if getData(key,@retVal,4)
    return retVal
  return -1
  
PUB setLong(key,value)
  setData(key,@value,4)

PUB getWord(key) | retVal
  retVal := 0
  if getData(key,@retVal,2)
    return retVal
  return -1
  
PUB setWord(key,value)
  setData(key,@value,2)

PUB getByte(key) | retVal
  retVal:=0
  if getData(key,@retVal,1)
    return retVal
  return -1
  
PUB setByte(key,value)
  setData(key,@value,1)
