{{
        ybox2 - settings object
        http://www.deepdarc.com/ybox2

        This object handles the storage and retreval of variables
        and data which need to persist across power cycles.

        Also allows for some rudamentry cross-object communication.
        It's not terribly fast though, so it should be read-from
        and written-to sparingly.

        Format is as follows

        2 Bytes                 Key Value
        1 Byte                  Key Length
        1 Byte                  Check Byte (Ones complement of key length)
        x Bytes                 Data
        1 Byte (Optional)       Padding, if size is odd
}} 
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  EEPROMPageSize = 128

  SettingsSize = $400
  SettingsTop = $8000 - 1
  SettingsBottom = SettingsTop - (SettingsSize-1)

  NET_MAC_ADDR  = $0100
  NET_IPv4_ADDR = $0101
  NET_IPv4_MASK = $0102
  NET_IPv4_GATE = $0103
  NET_IPv4_DNS  = $0104
  NET_DHCPv4_DISABLE = $0105
  
  SOUND_DISABLE = $0200
  
  MISC_CONFIGURED_FLAG = $0300 
  MISC_PASSWORD = $0301 
  MISC_AUTOBOOT = $0302
  
  SERVER_IPv4_ADDR = $0400 
  SERVER_IPv4_PORT = $0401 
  SERVER_PATH = $0402 
  SERVER_HOST = $0403 
DAT
SettingsLock  byte      -1
OBJ
  eeprom : "Basic_I2C_Driver"
PUB start | i,addr
  if(SettingsLock := locknew) == -1
    abort FALSE

  addr := SettingsBottom & %11111111_10000000
  eeprom.Initialize(eeprom#BootPin)
  repeat i from 0 to SettingsSize/EEPROMPageSize
    eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, addr+$8000, addr, SettingsSize)
    addr+=EEPROMPageSize
  return TRUE
   
PUB stop
  lockret(SettingsLock)
  SettingsLock := -1
PRI lock
  repeat while NOT lockset(SettingsLock)
PRI unlock
  lockclr(SettingsLock)
PUB commit | addr, i
  lock
  addr := SettingsBottom & %11111111_10000000
  eeprom.Initialize(eeprom#BootPin)
  repeat i from 0 to SettingsSize/EEPROMPageSize
    if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addr+$8000, addr, EEPROMPageSize)
      unlock
      abort FALSE
    repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addr+$8000)
    addr+=EEPROMPageSize
  unlock

PRI findKey_(key) | iter
  iter := SettingsTop
  repeat while (iter > SettingsBottom) AND word[iter] AND (byte[iter-2]==(byte[iter-3]^$FF))
    if word[iter] == key
      return iter
    iter-=4+((byte[iter-2]+1) & !1)
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
    if byte[iter-2] < size
      size := byte[iter-2]
    
    bytemove(ptr, iter-3-byte[iter-2], size)
  else
    size:=0
  unlock
  return size
PUB removeData(key) | iter, nextKey
  lock
  iter := findKey_(key)
  if iter
    nextKey := iter-3-byte[iter-2]
    bytemove(SettingsBottom+iter-nextKey+1,SettingsBottom, nextKey-SettingsBottom)
  unlock
  return iter
PUB setData(key,ptr,size) | iter
  removeData(key)
  lock
  iter := SettingsTop
  if size>255
    abort FALSE
  repeat while (iter > SettingsBottom) AND word[iter] AND (byte[iter-2]==(byte[iter-3]^$FF))
    iter-=4+((byte[iter-2]+1) & !1)
  if iter-3-size<SettingsBottom
    unlock
    abort FALSE
  word[iter]:=key
  byte[iter-2]:=size
  byte[iter-3]:=!size
  bytemove(iter-3-size,ptr,size)
  unlock
  return iter

PUB getString(key,ptr,size) | strlen
  ' Strings must be zero terminated.
  strlen:=getData(key,ptr,size-1)
  byte[ptr][strlen]:=0  
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