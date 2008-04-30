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

        The data is filled in from back to front, so that the
        size of settings area can be adjusted later without
        causing problems. This means that the actual order
        of things in memory is reverse of what you see above.

        Even though it is written stored from the top-down, the
        data is stored in its original order. In other words,
        the actual data contained in a variable isn't stored
        backward. Doing so would have made things more complicated
        without any obvious benefit.

        Currently requires a 64KB EEPROM to save things persistantly.
}} 
CON
  EEPROMPageSize = 128

  SettingsSize = $400
  SettingsTop = $8000 - 1
  SettingsBottom = SettingsTop - (SettingsSize-1)

  MISC_UUID          = ("I"<<8) + "D"
  MISC_PASSWORD      = ("P"<<8) + "W"
  MISC_AUTOBOOT      = ("A"<<8) + "B"
  MISC_SOUND_DISABLE = ("s"<<8) + "-"
  MISC_LED_CONF      = ("L"<<8) + "C" ' 4 bytes: red pin, green pin, blue pin, CC=0/CA=1
  MISC_TV_MODE       = ("t"<<8) + "v" ' 1 byte, 0=NTSC, 1=PAL

  MISC_STAGE_TWO     = ("S"<<8) + "2"

  NET_MAC_ADDR       = ("E"<<8) + "A"
  NET_IPv4_ADDR      = ("4"<<8) + "A"
  NET_IPv4_MASK      = ("4"<<8) + "M"
  NET_IPv4_GATE      = ("4"<<8) + "G"
  NET_IPv4_DNS       = ("4"<<8) + "D"
  NET_DHCPv4_DISABLE = ("4"<<8) + "d"
  
  SERVER_IPv4_ADDR   = ("S"<<8) + "A" 
  SERVER_IPv4_PORT   = ("S"<<8) + "P" 
  SERVER_PATH        = ("S"<<8) + "T" 
  SERVER_HOST        = ("S"<<8) + "H"

  
DAT
SettingsLock  byte      -1
OBJ
  eeprom : "Basic_I2C_Driver"
PUB start | i,addr
  if(SettingsLock := locknew) == -1
    abort FALSE

  if not size
    ' If we don't have any environment variables, try to load the defaults from EEPROM
    addr := SettingsBottom & %11111111_10000000
    eeprom.Initialize(eeprom#BootPin)
    repeat i from 0 to SettingsSize/EEPROMPageSize-1
      eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, addr+$8000, addr, SettingsSize)
      addr+=EEPROMPageSize
  return TRUE
PUB purge
  bytefill(SettingsBottom,$FF,SettingsSize) 
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
  repeat i from 0 to SettingsSize/EEPROMPageSize-1
    if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addr+$8000, addr, EEPROMPageSize)
      unlock
      abort FALSE
    repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addr+$8000)
    addr+=EEPROMPageSize
  unlock

pri isValidEntry(iter)
  return (iter > SettingsBottom) AND word[iter] AND (byte[iter-2]==(byte[iter-3]^$FF))
pri nextEntry(iter)
  return iter-(4+((byte[iter-2]+1) & !1))

PUB size | iter
  iter := SettingsTop
  repeat while isValidEntry(iter)
    iter:=nextEntry(iter)
  return SettingsTop-iter

PRI findKey_(key) | iter
  iter := SettingsTop
  repeat while isValidEntry(iter)
    if word[iter] == key
      return iter
    iter:=nextEntry(iter)
  return 0
PUB findKey(key) | retVal
  lock
  retVal:=findKey_(key)
  unlock
  return retVal
PUB firstKey
  if isValidEntry(SettingsTop)
    return word[SettingsTop]
  return 0

PUB nextKey(key) | iter
  lock
  iter:=nextEntry(findKey_(key))
  if isValidEntry(iter)
    key:=word[iter]
  else
    key:=0
  unlock
  return key
PUB getData(key,ptr,size_) | iter
  lock
  iter := findKey_(key)
  if iter
    if byte[iter-2] < size_
      size_ := byte[iter-2]
    
    bytemove(ptr, iter-3-byte[iter-2], size_)
  else
    size_:=0
  unlock
  return size_
PUB removeKey(key) | iter, nxtKey
  lock
  iter := findKey_(key)
  if iter
    nxtKey := nextEntry(iter)
    bytemove(SettingsBottom+iter-nxtKey,SettingsBottom, nxtKey-SettingsBottom+1)
  unlock
  return iter
PUB setData(key,ptr,size_) | iter
  removeKey(key)
  lock
  iter := SettingsTop
  if size_>255
    abort FALSE
  repeat while isValidEntry(iter)
    iter:=nextEntry(iter)
  if iter-3-size_<SettingsBottom
    unlock
    abort FALSE
  word[iter]:=key
  byte[iter-2]:=size_
  byte[iter-3]:=!size_
  bytemove(iter-3-size_,ptr,size_)
  unlock
  return iter

PUB getString(key,ptr,size_) | strlen
  ' Strings must be zero terminated.
  strlen:=getData(key,ptr,size_-1)
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