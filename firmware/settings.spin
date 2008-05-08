{{
        Settings Object v1.0
        Robert Quattlebaum <darco@deepdarc.com>
        PUBLIC DOMAIN
        
        This object handles the storage and retreval of variables
        and data which need to persist across power cycles.

        By default requires a 64KB EEPROM to save things persistantly.
        You can make it work with a 32KB EEPROM by changing the
        EEPROMOffset constant to zero.

        Also, since it is effectively a "singleton" type of object,
        it allows for some rudamentry cross-object communication.
        It is not terribly fast though, so it should be read-from
        and written-to sparingly.

        The data is stored at the end of hub ram, starting at $8000
        and expanding downward.

        The format is as follows (in reverse!):

        1 Word                  Key Value
        1 Byte                  Data Length
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
}} 
CON { Tweakable parameters }
  SettingsSize = $400
  EEPROMOffset = $8000 ' Change to zero if you want to use with a 32KB EEPROM

CON { Non-tweakable constants}
  EEPROMPageSize = 128
  SettingsTop = $8000 - 1
  SettingsBottom = SettingsTop - (SettingsSize-1)

CON { Keys for various stuff }
  MISC_UUID          = "i"+("d"<<8)
  MISC_PASSWORD      = "p"+("w"<<8)
  MISC_AUTOBOOT      = "a"+("b"<<8)
  MISC_SOUND_DISABLE = "s"+("-"<<8)
  MISC_LED_CONF      = "l"+("c"<<8) ' 4 bytes: red pin, green pin, blue pin, CC=0/CA=1
  MISC_TV_MODE       = "t"+("v"<<8) ' 1 byte, 0=NTSC, 1=PAL

  MISC_STAGE_TWO     = "2"+("2"<<8)

  NET_MAC_ADDR       = "E"+("A"<<8)
  NET_IPv4_ADDR      = "4"+("A"<<8)
  NET_IPv4_MASK      = "4"+("M"<<8)
  NET_IPv4_GATE      = "4"+("G"<<8)
  NET_IPv4_DNS       = "4"+("D"<<8)
  NET_DHCPv4_DISABLE = "4"+("d"<<8)
  
  SERVER_IPv4_ADDR   = "S"+("A"<<8) 
  SERVER_IPv4_PORT   = "S"+("P"<<8) 
  SERVER_PATH        = "S"+("T"<<8) 
  SERVER_HOST        = "S"+("H"<<8)

  
DAT
SettingsLock  byte      -1
OBJ
  eeprom : "Basic_I2C_Driver"
PUB start
{{ Initializes the object. Call only once. }}
  if(SettingsLock := locknew) == -1
    abort FALSE

  eeprom.Initialize(eeprom#BootPin)

  ' If we don't have any environment variables, try to load the defaults from EEPROM
  if not size
    revert

  return TRUE
PUB revert | i, addr
{{ Retrieves the settings from EEPROM, overwriting any changes that were made. }}  
  lock
  addr := SettingsBottom & %11111111_10000000
  repeat i from 0 to SettingsSize/EEPROMPageSize-1
    eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, addr+EEPROMOffset, addr, SettingsSize)
    addr+=EEPROMPageSize
  unlock
PUB purge
{{ Removes all settings. }}
  lock
  bytefill(SettingsBottom,$FF,SettingsSize) 
  unlock
PUB stop
  lockret(SettingsLock)
  SettingsLock := -1
PRI lock
  repeat while NOT lockset(SettingsLock)
PRI unlock
  lockclr(SettingsLock)
PUB commit | addr, i
{{ Commits current settings to EEPROM }}
  lock
  addr := SettingsBottom & %11111111_10000000
  eeprom.Initialize(eeprom#BootPin)
  repeat i from 0 to SettingsSize/EEPROMPageSize-1
    if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addr+EEPROMOffset, addr, EEPROMPageSize)
      unlock
      abort FALSE
    repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addr+EEPROMOffset)
    addr+=EEPROMPageSize
  unlock

pri isValidEntry(iter)
  return (iter > SettingsBottom) AND word[iter] AND (byte[iter-2]==(byte[iter-3]^$FF))
pri nextEntry(iter)
  return iter-(4+((byte[iter-2]+1) & !1))

PUB size | iter
{{ Returns the current size of all settings }}
  iter := SettingsTop
  repeat while isValidEntry(iter)
    iter := nextEntry(iter)
  return SettingsTop-iter

PRI findKey_(key) | iter
  iter := SettingsTop
  repeat while isValidEntry(iter)
    if word[iter] == key
      return iter
    iter:=nextEntry(iter)
  return 0
PUB findKey(key):retVal
{{ Returns non-zero if the given key exists in the store }}
  lock
  retVal:=findKey_(key)
  unlock
PUB firstKey
{{ Returns the key of the first setting }}
  if isValidEntry(SettingsTop)
    return word[SettingsTop]
  return 0

PUB nextKey(key) | iter
{{ Finds and returns the key of the setting after the given key }}
  lock
  iter:=nextEntry(findKey_(key))
  if isValidEntry(iter)
    key:=word[iter]
  else
    key~
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
    size_~
  unlock
  return size_
PUB removeKey(key): iter
  lock
  iter := findKey_(key)
  if iter
    key := nextEntry(iter)
    bytemove(SettingsBottom+iter-key,SettingsBottom, key-SettingsBottom+1)
  unlock
PUB setData(key,ptr,size_): iter

  ' We set a value by first removing
  ' the previous value and then
  ' appending the value at the end.
  
  removeKey(key)

  lock
  iter := SettingsTop

  ' Runtime sanity check.
  if size_>255
    abort FALSE

  ' Traverse to the end of the last setting
  repeat while isValidEntry(iter)
    iter:=nextEntry(iter)

  ' Make sure there is enough space left
  if iter-3-size_<SettingsBottom
    unlock
    abort FALSE

  ' Append the new setting  
  word[iter]:=key
  byte[iter-2]:=size_
  byte[iter-3]:=!size_
  bytemove(iter-3-size_,ptr,size_)

  ' Make sure that this is the last entry.
  iter:=nextEntry(iter)
  if isValidEntry(iter)
    word[iter]~~
    word[iter-1]~~
      
  unlock

PUB getString(key,ptr,size_): strlen
  strlen:=getData(key,ptr,size_-1)
  ' Strings must be zero terminated.
  byte[ptr][strlen]:=0  
  
PUB setString(key,ptr)
  return setData(key,ptr,strsize(ptr))  
  
PUB getLong(key): retVal
  getData(key,@retVal,4)
  
PUB setLong(key,value)
  return setData(key,@value,4)

PUB getWord(key): retVal
  getData(key,@retVal,2)
  
PUB setWord(key,value)
  return setData(key,@value,2)

PUB getByte(key): retVal
  getData(key,@retVal,1)
  
PUB setByte(key,value)
  return setData(key,@value,1)
CON
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}