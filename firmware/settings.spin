CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  EEPROMPageSize = 128

  SettingsPtr = $7000
  SettingsSize = $FF


  NET_MAC_ADDR  = $0100
  NET_IPv4_ADDR = $0101
  NET_IPv4_MASK = $0102
  NET_IPv4_GATE = $0103
  NET_IPv4_DNS  = $0104
  NET_DHCPv4_DISABLE = $0105
  
  SOUND_DISABLE = $0200
  

OBJ
  eeprom : "Basic_I2C_Driver"
PUB start
PUB stop
PUB commit | addr
  addr := SettingsPtr & %11111111_10000000
  eeprom.Initialize(eeprom#BootPin)
  if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addr, addr, 128)
    abort FALSE

PUB findKey(key) | iter
  iter := SettingsPtr
  repeat while (iter < SettingsPtr+SettingsSize) AND long[iter] AND word[iter+4]
    if long[iter] == key
      return iter
    iter+=6+word[iter+4]
  return 0
PUB getData(key,ptr,size) | iter
  iter := findKey(key)
  if iter
    bytemove(ptr, iter+6, size #> word[iter+4])
  return iter
PUB removeData(key) | iter, nextKey
  iter := findKey(key)
  if iter
    nextKey := iter+6+word[iter+4]
    bytemove(iter,nextKey, SettingsSize - (nextKey-SettingsPtr))
  return iter
PUB setData(key,ptr,size) | iter
  removeData(key)
  iter := SettingsPtr
  repeat while (iter < SettingsPtr+SettingsSize) AND long[iter] AND word[iter+4]
    iter+=6+word[iter+4]
  if iter+6+size>SettingsPtr+SettingsSize
    abort FALSE
  long[iter]:=key
  word[iter+4]:=size
  bytemove(iter+6,ptr,size)
  return iter
  
PUB getLong(key) | retVal
  if getData(key,@retVal,4)
    return retVal
  return -1
  
PUB setLong(key,value)
  setData(key,value,4)

PUB getWord(key) | retVal
  retVal := 0
  if getData(key,@retVal,2)
    return retVal
  return -1
  
PUB setWord(key,value)
  setData(key,value,2)

PUB getByte(key) | retVal
  retVal:=0
  if getData(key,@retVal,1)
    return retVal
  return -1
  
PUB setByte(key,value)
  setData(key,value,1)
