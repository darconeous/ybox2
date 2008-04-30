{{
        ybox2 - bootloader object
        http://www.deepdarc.com/ybox2

        Designed for use with a 64KB EEPROM. It will not work
        properly with a 32KB EEPROM.

        If your pin assignments are different, you'll need to
        change them here and in the subsys object.

}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      

OBJ

  websocket     : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  eeprom        : "Basic_I2C_Driver"
  random        : "RealRandom"
  base64        : "base64"
  http          : "http"
VAR
  long stack[10] 
  byte stage_two
DAT
productName   BYTE      "ybox2 bootloader v0.9",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0
productURL2    BYTE      "http://www.ladyada.net/make/ybox2/",0

PUB init | i, tv_mode
  dira[0]:=1 ' Set direction on reset pin
  outa[0]:=0 ' Set state on reset pin to LOW

  ' Default to NTSC
  tv_mode:=term#MODE_NTSC
  
  ' Load persistent environment settings  
  settings.start  

  ' Set the direction on the sound pin depending
  ' on if we are muted or not.
  if settings.findKey(settings#MISC_SOUND_DISABLE) == FALSE
    dira[subsys#SPKRPin]:=1
  else
    dira[subsys#SPKRPin]:=0

  ' If we are in the second stage of a bootloader upgrade,
  ' then we need set the appropriate variable.
  if settings.findKey(settings#MISC_STAGE_TWO)
    stage_two := TRUE
    settings.removeKey(settings#MISC_STAGE_TWO)
  else
    stage_two := FALSE

  ' Fire up the almighty subsys
  subsys.init
  subsys.StatusLoading

  ' If there is a TV mode preference in the EEPROM, load it up.
  if settings.findKey(settings#MISC_TV_MODE)
    tv_mode := settings.getByte(settings#MISC_TV_MODE)
    
  ' Start the TV Terminal
  term.startWithMode(12,tv_mode)

  ' Output the title, URLs, and squigly line.
  printBanner

  if NOT stage_two AND settings.findKey(settings#MISC_AUTOBOOT)
    delay_ms(2000)
    if NOT ina[subsys#BTTNPin]
      boot_stage2
    else
      term.str(string("Autoboot Aborted.",13))
      subsys.chirpSad    

  if NOT settings.findKey(settings#NET_MAC_ADDR)
    if NOT \initial_configuration
      term.str(string("Initial configuration failed!",13))
      subsys.StatusFatalError
      subsys.chirpSad
      waitcnt(clkfreq*100000 + cnt)
      reboot

  ' Print out the MAC address on the TV
  if settings.getData(settings#NET_MAC_ADDR,@stack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@stack][i],2)
    term.out(13)  

  ' If the user is holding down the button, wait two seconds.
  repeat 10
    if ina[subsys#BTTNPin]
      delay_ms(200)
    
  ' If the button is still being held down, then
  ' assume we are in a password reset condition.
  if ina[subsys#BTTNPin]
    subsys.chirpHappy
    subsys.chirpSad
    subsys.chirpHappy
    subsys.chirpSad
    subsys.chirpHappy
    if ina[subsys#BTTNPin]
      term.str(string("RESET MODE",13))
      subsys.chirpSad
      resetSettings
      subsys.chirpHappy
      reboot

  outa[0]:=1 ' Pull ethernet reset pin high, ending the reset condition.
  if not \websocket.start(1,2,3,4,6,7,-1,-1)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    subsys.chirpSad
    outa[0]:=0 ' Pull ethernet reset pin low, starting a reset condition.
    ' Reboot after 20 seconds.
    waitcnt(clkfreq*20000 + cnt)
    reboot

  ' Make a happy noise, we are moving along!
  subsys.chirpHappy

  ' Wait for the IP address if we don't already have one.
  if NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
    term.str(string("IPv4 ADDR: DHCP..."))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
      delay_ms(500)
    term.out($0A)
    term.out($00)  

  ' Output the IP address we have aquired.
  term.str(string("IPv4 ADDR: "))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@stack][i])
  term.out(13)  

  ' If we have a DNS address, print that out too.
  if settings.getData(settings#NET_IPv4_DNS,@stack,4)
    term.str(string("DNS ADDR: "))
    repeat i from 0 to 3
      if i
        term.out(".")
      term.dec(byte[@stack][i])
    term.out(13)  

  if stage_two
    subsys.StatusSolid(255,255,255)
    term.str(string("BOOTLOADER UPGRADE",13,"STAGE TWO",13))
  else
    subsys.StatusIdle

  ' Infinite loop
  repeat
    \httpServer
    term.str(string("WEBSERVER EXCEPTION",13))
PRI resetSettings | key, nextKey
'' Preforms a "factory reset" by removing all
'' settings except those used for device identification
'' and hardware configuration.
  key:=settings.firstKey
  ifnot key
    return
  repeat
    nextKey:=settings.nextKey(key)
    case key
      settings#NET_MAC_ADDR:   ' Preserve MAC Address
      settings#MISC_UUID:      ' Preserve UUID
      settings#MISC_LED_CONF:  ' Preserve LED Configuration
      other: settings.removeKey(key)
  while (key:=nextKey)

  settings.commit
  
PRI boot_stage2 | i
  settings.setByte(settings#MISC_STAGE_TWO,TRUE)
 
  outa[0]:=0 ' Pull ethernet reset pin low, starting a reset condition.

  ' Very aggressively shut down every other COG except our own.
  repeat i from 0 to 7
    if cogid<>i
      cogstop(i)

  ' Replace this cog with the bootloader
  coginit(0,@bootstage2,0)

  ' Just in case...
  cogstop(cogid)
PRI initial_configuration | i
  term.str(string("First boot!",13))

  settings.purge
  
  random.start

  ' Make a random UUID
  repeat i from 0 to 16
    byte[@stack][i] := random.random
  settings.setData(settings#MISC_UUID,@stack,16)

  ' Make a random MAC Address
  byte[@stack][0] := $02
  repeat i from 1 to 5
    byte[@stack][i] := random.random
  settings.setData(settings#NET_MAC_ADDR,@stack,6)

  random.stop
  
  ' RGB LED Configuration
  ' Original board = $000A0B09
  ' Adafruit board = $010B0A09 (This is the default)
  'settings.setLong(settings#MISC_LED_CONF,$010B0A09)
  'settings.setLong(settings#MISC_LED_CONF,$000A0B09)

  settings.commit
  return TRUE

PUB atoi(inptr) | i,char, retVal
  retVal:=0
  
  ' Skip leading whitespace
  repeat while BYTE[inptr] AND BYTE[inptr]==" "
    inptr++
   
  repeat 10
    case (char := BYTE[inptr++])
      "0".."9":
        retVal:=retVal*10+char-"0"
      OTHER:
        return retVal
  return retVal 
pri printBanner
  term.str(string($0C,7))
  term.str(@productName)
  term.out(13)
  term.str(@productURL)
  term.out(13)
  term.str(@productURL2)
  term.out(13)
  term.out($0c)
  term.out(2)
  repeat term#cols/2
    term.out($8E)
    term.out($88)
  term.out($0c)
  term.out(0)

pri buttonCheck
  if ina[subsys#BTTNPin]
    ' If the user is holding down the button, wait two seconds.
    repeat 10
      if ina[subsys#BTTNPin]
        delay_ms(200)

    if ina[subsys#BTTNPin]
      ' The user is still holding down the button.
      ' They must want to change the video mode!

      term.stop

      if NOT settings.findKey(settings#MISC_TV_MODE) OR settings.getByte(settings#MISC_TV_MODE)==0
        settings.removeKey($1010)
        settings.setByte(settings#MISC_TV_MODE,term#MODE_PAL)
        term.startWithMode(12,term#MODE_PAL)
        printBanner
        term.str(string("PAL Mode Selected",13))
      else
        settings.removeKey($1010)
        settings.setByte(settings#MISC_TV_MODE,term#MODE_NTSC)
        term.startWithMode(12,term#MODE_NTSC)
        printBanner
        term.str(string("NTSC Mode Selected",13))

      settings.commit
      subsys.chirpHappy

      ' Wait for the user to let go
      repeat while ina[subsys#BTTNPin]
    else
      ' The user let go... They must just want to boot to stage2
      boot_stage2
    
  
VAR
  byte buffer [128]
  byte buffer2 [128]
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[64]
  byte httpHeader[32]

DAT
HTTP_200      BYTE      "HTTP/1.1 200 OK"
CR_LF         BYTE      13,10,0
HTTP_303      BYTE      "HTTP/1.1 303 See Other",13,10,0
HTTP_404      BYTE      "HTTP/1.1 404 Not Found",13,10,0
HTTP_403      BYTE      "HTTP/1.1 403 Forbidden",13,10,0
HTTP_401      BYTE      "HTTP/1.1 401 Authorization Required",13,10,0
HTTP_411      BYTE      "HTTP/1.1 411 Length Required",13,10,0
HTTP_501      BYTE      "HTTP/1.1 501 Not Implemented",13,10,0

HTTP_HEADER_SEP     BYTE ": ",0
HTTP_HEADER_CONTENT_TYPE BYTE "Content-Type",0
HTTP_HEADER_LOCATION     BYTE "Location",0
HTTP_HEADER_CONTENT_DISPOS     BYTE "Content-disposition",0
HTTP_HEADER_CONTENT_LENGTH     BYTE "Content-Length",0

HTTP_CONTENT_TYPE_HTML  BYTE "text/html; charset=utf-8",0
HTTP_CONNECTION_CLOSE   BYTE "Connection: close",13,10,0

RAMIMAGE_EEPROM_FILE    BYTE "/ramimage.eeprom",0
STAGE2_EEPROM_FILE      BYTE "/stage2.eeprom",0
CONFIG_BIN_FILE         BYTE "/config.bin",0

pri httpOutputLink(url,class,content)
  websocket.str(string("<a href='"))
  websocket.strxml(url)
  if class
    websocket.str(string("' class='"))
    websocket.strxml(class)
  websocket.str(string("'>"))
  websocket.str(content)
  websocket.str(string("</a>"))
  

pri httpUnauthorized
  websocket.str(@HTTP_401)
  websocket.str(@HTTP_CONNECTION_CLOSE)
  websocket.txMimeHeader(string("WWW-Authenticate"),string("Basic realm='ybox2'"))
  websocket.str(@CR_LF)
  websocket.str(@HTTP_401)

pri httpNotFound
  websocket.str(@HTTP_404)
  websocket.str(@HTTP_CONNECTION_CLOSE)
  websocket.str(@CR_LF)
  websocket.str(@HTTP_404)

     
pub httpServer | char, i,j, lineLength,contentLength,authorized
  repeat
    repeat while \websocket.listen(80) == -1
      buttonCheck
      delay_ms(1000)
      websocket.closeall
      next
    websocket.resetBuffers
    contentLength:=0

    repeat while NOT websocket.waitConnectTimeout(100)
      buttonCheck
      
    http.parseRequest(websocket.handle,@httpMethod,@httpPath,@httpQuery)

    ' If there isn't a password set, then we are by default "authorized"
    authorized:=NOT settings.findKey(settings#MISC_PASSWORD)

    repeat while http.getNextHeader(websocket.handle,@httpHeader,32,@buffer,128)
      if strcomp(@httpHeader,@HTTP_HEADER_CONTENT_LENGTH)
        contentLength:=atoi(@buffer)
      elseif NOT authorized AND strcomp(@httpHeader,string("Authorization"))
        ' Skip past the word "Basic"
        repeat i from 0 to 7
          if buffer[i]==" "
            i++
            quit
          if buffer[i]==0
            quit
        base64.inplaceDecode(@buffer+i)  
        settings.getString(settings#MISC_PASSWORD,@buffer2,127)
        authorized:=strcomp(@buffer+i,@buffer2)

    ' Authorization check
    ' You can comment this out if you want to
    ' be able to let unauthorized people see the
    ' front page. They won't be able to upload
    ' or download firmware, or change settings
    ' without being authorized because those
    ' actions check for authorization anyway.
    'ifnot authorized
    '  httpUnauthorized
    '  next
             
    if strcomp(@httpMethod,string("GET")) or strcomp(@httpMethod,string("POST"))
      if strcomp(@httpPath,string("/"))
        websocket.str(@HTTP_200)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,@HTTP_CONTENT_TYPE_HTML)        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        indexPage(authorized)
      elseif strcomp(@httpPath,string("/info"))
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        infoPage
      elseif strcomp(@httpPath,string("/password"))
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        i:=0
        repeat while contentLength AND i<127
          char:=websocket.rxtime(1000)
          buffer[i++]:=char
          contentLength--
        buffer[i]:=0
        buffer2[0]:=0
        i:=http.getFieldFromQuery(@buffer,string("username"),@buffer2,127)
        if i
          buffer2[i++]:=":"
          j:=http.getFieldFromQuery(@buffer,string("pwd1"),@buffer2+i,63)
          ifnot j
             i:=0
          else
            j:=http.getFieldFromQuery(@buffer,string("pwd2"),@httpQuery,63)
          if j==0 OR NOT strcomp(@httpQuery,@buffer2+i)
            i:=0
         
        ifnot i
          websocket.str(string("HTTP/1.1 400 Bad Request",13,10))
          websocket.str(@HTTP_CONNECTION_CLOSE)
          websocket.str(@CR_LF)
          websocket.str(string("Passwords didn't match.",13,10))
        else
          settings.removeKey($1010)
          settings.setString(settings#MISC_PASSWORD,@buffer2)  
          settings.commit
           
          websocket.str(@HTTP_303)
          websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
          websocket.str(@HTTP_CONNECTION_CLOSE)
          websocket.str(@CR_LF)
          websocket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/reboot"))
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("REBOOTING",13,10))
        websocket.close
        outa[0]:=0 ' Pull ethernet reset pin low, starting a reset condition.
        reboot
      elseif strcomp(@httpPath,string("/irtest"))
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        subsys.irTest
        websocket.str(string("Status LED should now blink on IR activity.",13,10))
      elseif strcomp(@httpPath,string("/stage2"))
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("BOOTING STAGE 2",13,10))
        websocket.close
        boot_stage2
      elseif strcomp(@httpPath,string("/login"))
        ifnot authorized
          httpUnauthorized
          websocket.close                                                               
          next
        websocket.str(@HTTP_303)
        websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/ledconfig"))
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        if httpQuery[0]=="1"
          settings.removeKey($1010)
          settings.setLong(settings#MISC_LED_CONF,$000A0B09)
          settings.commit
          websocket.str(string("ENABLED (NEEDS REBOOT)",13,10))
        else
          settings.removeKey($1010)
          settings.removeKey(settings#MISC_LED_CONF)
          settings.commit
          websocket.str(string("DISABLED (NEEDS REBOOT)",13,10))
      elseif strcomp(@httpPath,string("/autoboot"))
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        websocket.str(@HTTP_303)
        websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        if httpQuery[0]=="1"
          settings.removeKey($1010)
          settings.setByte(settings#MISC_AUTOBOOT,1)
          settings.commit
          websocket.str(string("ENABLED",13,10))
        else
          settings.removeKey($1010)
          settings.removeKey(settings#MISC_AUTOBOOT)
          settings.commit
          websocket.str(string("DISABLED",13,10))
      elseif strcomp(@httpPath,RAMIMAGE_EEPROM_FILE)
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-eeprom"))        
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=ramimage.eeprom"))        
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_LENGTH,string("32768"))        
        websocket.str(@CR_LF)
        repeat i from 0 to $7FFF
          websocket.tx(BYTE[i])
      elseif strcomp(@httpPath,STAGE2_EEPROM_FILE)
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-eeprom"))        
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=stage2.eeprom"))        
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_LENGTH,string("32768"))        
        websocket.str(@CR_LF)
        repeat i from 0 to $7FFF step 128
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
            quit
          repeat j from 0 to 127
            websocket.tx(buffer[j])
      elseif strcomp(@httpPath,@CONFIG_BIN_FILE)
        ifnot authorized
          httpUnauthorized
          websocket.close
          next
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-bin"))        
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=config.bin"))        
        websocket.str(@HTTP_HEADER_CONTENT_LENGTH)
        websocket.str(string(": "))
        websocket.dec(settings#SettingsSize)
        websocket.str(@CR_LF)        
        websocket.str(@CR_LF)
        repeat i from settings#SettingsBottom to settings#SettingsTop step 128
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
            quit
          repeat j from 0 to 127
            websocket.tx(buffer[j])
      else           
        httpNotFound
    elseif strcomp(@httpMethod,string("PUT"))
      ifnot authorized
        httpUnauthorized
        websocket.close
        next
      if not contentLength
        websocket.str(@HTTP_411)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(@HTTP_411)
      elseif strcomp(@httpPath,@RAMIMAGE_EEPROM_FILE) OR strcomp(@httpPath,@CONFIG_BIN_FILE)
        websocket.str(@HTTP_403)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(@HTTP_403)
      elseif strcomp(@httpPath,@STAGE2_EEPROM_FILE)
        if (i:=\downloadFirmwareHTTP(contentLength))
          subsys.chirpSad
          subsys.StatusFatalError
          websocket.str(string("HTTP/1.1 400 Bad Request",13,10))
          websocket.str(@HTTP_CONNECTION_CLOSE)
          websocket.str(@CR_LF)
          websocket.str(string("Upload Failure",13,10))
          websocket.dec(i)         
          websocket.str(@CR_LF)
        else
          if strcomp(@httpQuery,string("boot")) OR stage_two
            websocket.str(@HTTP_303)
            websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
            websocket.str(@HTTP_CONNECTION_CLOSE)
            websocket.str(@CR_LF)
            if stage_two
              websocket.str(string("OK - Rebooting",13,10))
              websocket.close
              outa[0]:=0 ' Pull ethernet reset pin low, starting a reset condition.
              reboot
            else
              websocket.str(string("OK - Booting stage 2",13,10))
              websocket.close
              boot_stage2
          else
            websocket.str(@HTTP_303)
            websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
            websocket.str(@HTTP_CONNECTION_CLOSE)
            websocket.str(@CR_LF)
            websocket.str(string("OK",13,10))
      else
        httpNotFound
    else
      websocket.str(@HTTP_501)
      websocket.str(@HTTP_CONNECTION_CLOSE)
      websocket.str(@CR_LF)
      websocket.str(@HTTP_501)
    
    websocket.close
pub infoPage | i

  if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
    websocket.str(string("ybox.macaddr = '"))
    repeat i from 0 to 5
      if i
        websocket.tx("-")
      websocket.hex(byte[@httpMethod][i],2)
    websocket.str(string("'",10))

  if settings.getData(settings#MISC_UUID,@httpQuery,16)
    websocket.str(string("ybox.uuid = '"))
    repeat i from 0 to 3
      websocket.hex(byte[@httpQuery][i],2)
    websocket.tx("-")
    repeat i from 4 to 5
      websocket.hex(byte[@httpQuery][i],2)
    websocket.tx("-")
    repeat i from 6 to 7
      websocket.hex(byte[@httpQuery][i],2)
    websocket.tx("-")
    repeat i from 8 to 9
      websocket.hex(byte[@httpQuery][i],2)
    websocket.tx("-")
    repeat i from 10 to 15
      websocket.hex(byte[@httpQuery][i],2)
    websocket.str(string("'",10))
    
  websocket.str(string("ybox.uptime = "))
  websocket.dec(subsys.RTC)
  websocket.tx(10)
  websocket.str(string("ybox.ina = "))
  websocket.dec(ina)
  websocket.tx(10)
pub beginInfo
    websocket.str(string("<div><tt>"))
pub endInfo
    websocket.str(string("</tt></div>"))

pub beginForm(action,method)
  websocket.str(string("<form action='"))
  websocket.str(action)
  websocket.str(string("' method='"))
  websocket.str(method)
  websocket.str(string("'>"))
pub endForm
  websocket.str(string("</form>"))
pub addTextField(id,label,value,length)
  websocket.str(string("<div><label for='"))
  websocket.str(id)
  websocket.str(string("'>"))
  websocket.str(label)
  websocket.str(string(":</label><input name='"))
  websocket.str(id)
  websocket.str(string("' id='"))
  websocket.str(id)
  websocket.str(string("' size='"))
  websocket.dec(length)
  websocket.str(string("' value='"))
  websocket.strxml(value)
  websocket.str(string("' /></div>"))
pub addPasswordField(id,label,value,length)
  websocket.str(string("<div><label for='"))
  websocket.str(id)
  websocket.str(string("'>"))
  websocket.str(label)
  websocket.str(string(":</label><input type='password' name='"))
  websocket.str(id)
  websocket.str(string("' id='"))
  websocket.str(id)
  websocket.str(string("' size='"))
  websocket.dec(length)
  if value
    websocket.str(string("' value='"))
    websocket.strxml(value)
  websocket.str(string("' /></div>"))
pub addSubmitButton
  websocket.str(string("<input type='submit' />"))
  
pub indexPage(authorized) | i
  websocket.str(string("<html><head><meta name='viewport' content='width=320' /><title>ybox2</title>"))
  websocket.str(string("<link rel='stylesheet' href='http://www.uscity.net/iphone/iPhoneButtons.css' />"))
  websocket.str(string("<style>body { margin: 8px; background-color: rgb(197,204,211); font-family: Helvetica; } .button { width: 240px; } h1 { text-align: center; } h2 { color: rgb(76,86,108); }</style>"))

 

  websocket.str(string("</head><body><h1>"))
  websocket.str(@productName)
  websocket.str(string("</h1>"))

  if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
    beginInfo
    websocket.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        websocket.tx("-")
      websocket.hex(byte[@httpMethod][i],2)
    endInfo

  beginInfo
  websocket.str(string("Uptime: "))
  websocket.dec(subsys.RTC/3600)
  websocket.tx("h")
  websocket.dec(subsys.RTC/60//60)
  websocket.tx("m")
  websocket.dec(subsys.RTC//60)
  websocket.tx("s")
  endInfo
   
  beginInfo
  websocket.str(string("Autoboot: "))
  if settings.findKey(settings#MISC_AUTOBOOT)  
    websocket.str(string("<b>ON</b> "))
    if authorized
      httpOutputLink(string("/autoboot?0"),0,string("disable"))
  else
    websocket.str(string("<b>OFF</b> "))
    if authorized
      httpOutputLink(string("/autoboot?1"),0,string("enable"))
  endInfo
   
  beginInfo
  websocket.str(string("Password: "))
  if settings.findKey(settings#MISC_PASSWORD)
    websocket.str(string("SET"))  
  else
    websocket.str(string("NOT SET"))  
  endInfo
   
   
  if authorized
    beginForm(string("\password"),string("POST"))
    addTextField(string("username"),string("Username"),string("admin"),32)
    addPasswordField(string("pwd1"),string("Password"),0,32)
    addPasswordField(string("pwd2"),string("Password"),0,32)
    addSubmitButton 
    endForm
   
  websocket.str(string("<h2>Actions</h2>"))
  websocket.str(string("<p>"))
  httpOutputLink(string("/stage2"),string("white button"),string("Boot stage 2"))
  websocket.str(string("</p><p>"))
  httpOutputLink(string("/irtest"),string("blue button"),string("IR Test Mode"))
  websocket.str(string("</p><p>"))
  httpOutputLink(string("/reboot"),string("black button"),string("Reboot"))
  ifnot authorized
    websocket.str(string("</p><p>"))
    httpOutputLink(string("/login"),string("blackRight button"),string("Login"))
  websocket.str(string("</p>"))
   
   
  websocket.str(string("<h2>Files</h2>"))
  beginInfo
  httpOutputLink(@RAMIMAGE_EEPROM_FILE,0,@RAMIMAGE_EEPROM_FILE+1)
  websocket.tx(" ")
  httpOutputLink(@STAGE2_EEPROM_FILE,0,@STAGE2_EEPROM_FILE+1)
  websocket.tx(" ")
  httpOutputLink(@CONFIG_BIN_FILE,0,@CONFIG_BIN_FILE+1)
  endInfo
   
  websocket.str(string("<h2>Other</h2>"))
  beginInfo
  httpOutputLink(@productURL,0,@productURL)
  endInfo
  beginInfo
  httpOutputLink(@productURL2,0,@productURL2)
  endInfo

  websocket.str(string("</body></html>",13,10))

pub downloadFirmwareHTTP(contentLength) | timeout, retrydelay,in, i, total, addr,j
  eeprom.Initialize(eeprom#BootPin)

  i:=0
  total:=0
  
  if stage_two
    addr:=$0000 ' Stage two writes to the lower 32KB
  else
    addr:=$8000 ' Stage one writes to the upper 32KB

  if contentLength > $8000-settings#SettingsSize
    contentLength:=$8000-settings#SettingsSize
   
  repeat
    if (in := websocket.rxcheck) => 0
      subsys.StatusSolid(0,128,0)
      buffer[i++] := in
      if i == 128
        ' flush to EEPROM                              
        subsys.StatusSolid(0,0,128)
        if stage_two
          'Verify that the bytes we got match the EEPROM
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
            abort -1
          repeat i from 0 to 127
            if buffer[i] <> buffer2[i]
              term.str(string(13,"Verify failed.",13))
              abort -2
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort -3
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
        total+=i
        i:=0
        bytefill(@buffer,0,128)
        
        term.out(".")
      if total => $8000-settings#SettingsSize
        websocket.close
    else
      subsys.StatusSolid(128,0,0)
      if websocket.isEOF OR (total+i) => contentLength
        if stage_two
          ' Do we have the correct number of bytes?
          if settings.findKey($1010) AND ((total+i) <> settings.getWord($1010))
            subsys.chirpSad
            term.out(13)
            term.dec((total+i) - settings.getWord($1010))
            term.str(string(" byte diff!",13))
            abort -4                     

          'Verify that the bytes we got match the EEPROM
          if i
            if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
              abort -1
            repeat j from 0 to i-1
              if buffer[j] <> buffer2[j]
                term.str(string(13,"Verify failed: "))
                term.dec(buffer[j])
                term.out(" ")
                term.dec(buffer2[j])
                abort -5

          total+=i

          'If we got to this point, then everything matches! Write it out
          subsys.StatusLoading
          subsys.chirpHappy

          term.str(string(13,"Writing",13))

          repeat i from 0 to total-1 step 128
            if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
              abort -6
            if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, i, @buffer, 128)
              abort -7
            repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, i)
            term.out(".")
          ' Now we need to fill in the rest of the image with zeros.
          bytefill(@buffer,0,128)
          repeat j from i to $8000-settings#SettingsSize step 128
            subsys.StatusSolid(0,0,128)
            if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, j, @buffer, 128)
              abort -9
            subsys.StatusSolid(0,128,0)
            repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, j)
            term.out(".")
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort -8
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
          ' Now we need to fill in the rest of the image with zeros.
          bytefill(@buffer,0,128)
          repeat j from total+128 to $8000-settings#SettingsSize-1 step 128
            subsys.StatusSolid(0,0,128)
            if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, j+addr, @buffer, 128)
              abort -9
            subsys.StatusSolid(0,128,0)
            repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, i)
            term.out(".")

          total+=i
        
        ' done!
        term.str(string("done.",13))
        term.dec(total)
        term.str(string(" bytes written",13))
        subsys.chirpHappy
        subsys.StatusSolid(0,255,0)
        settings.setWord($1010,total)
        return 0


  return 0

PUB showMessage(str)
  term.str(string($1,$B,12,$C,$1))    
  term.str(str)    
  term.str(string($C,$8))    

PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
DAT
        org
' Taken from the propeller booter code, supplied by Parallax.

' Load ram from eeprom and launch
'
bootstage2              
                        clkset  zero
                        mov     raddress,zero
                        call    #ee_read                'send read command
:loop                   call    #ee_receive             'get eeprom byte
                        wrbyte  eedata,raddress          'write to ram
                        add     address,#1              'inc address
                        add     raddress,#1              'inc address
                        djnz    count,#:loop            'loop until done
                        call    #ee_stop                'end read (followed by launch)
'
'
' Launch program in ram
'
launch                  rdword  address,#$0004+2        'if pbase address invalid, shutdown
                        cmp     address,#$0010  wz
        if_nz           jmp     #shutdown

                        rdbyte  address,#$0004          'if xtal/pll enabled, start up now
                        and     address,#$F8            '..while remaining in rcfast mode
                        clkset  address

:delay                  djnz    time_xtal,#:delay       'allow 20ms @20MHz for xtal/pll to settle

                        rdbyte  address,#$0004          'switch to selected clock
                        clkset  address

                        coginit interpreter             'reboot cog with interpreter

                        ' Stop this cog.
                        cogid   address
                        cogstop address
'
'
' Shutdown
'
shutdown
                        'jmp shutdown
                        mov     smode,#$1FF              'reboot actualy
                        'mov     smode,#$02              'reboot actualy
                        clkset  smode                   '(reboot)
'                       
'
'**************************************
'* I2C routines for 24x256/512 EEPROM *
'* assumes fastest RC timing - 20MHz  *
'*   SCL low time  =  8 inst, >1.6us  *
'*   SCL high time =  4 inst, >0.8us  *
'*   SCL period    = 12 inst, >2.4us  *
'**************************************
'
'
' Begin eeprom read
'
ee_read                 mov     address,h8000           'reset address to $8000, the upper half of the EEPROM

                        call    #ee_write               'begin write (sets address)

                        mov     eedata,#$A1             'send read command
                        call    #ee_start
        if_c            jmp     #shutdown               'if no ack, shutdown

                        mov     count,programsize             'set count to programsize

ee_read_ret             ret
'
'
' Begin eeprom write
'
ee_write                call    #ee_wait                'wait for ack and begin write

                        mov     eedata,address          'send high address
                        shr     eedata,#8
                        call    #ee_transmit
        if_c            jmp     #shutdown               'if no ack, shutdown

                        mov     eedata,address          'send low address
                        call    #ee_transmit
        if_c            jmp     #shutdown               'if no ack, shutdown

ee_write_ret            ret
'
'
' Wait for eeprom ack
'
ee_wait                 mov     count,#400              '       400 attempts > 10ms @20MHz
:loop                   mov     eedata,#$A0             '1      send write command
                        call    #ee_start               '132+
        if_c            djnz    count,#:loop            '1      if no ack, loop until done

        if_c            jmp     #shutdown               '       if no ack, shutdown

ee_wait_ret             ret
'
'
' Start + transmit
'
ee_start                mov     bits,#9                 '1      ready 9 start attempts
:loop                   andn    outa,mask_scl           '1(!)   ready scl low
                        or      dira,mask_scl           '1!     scl low
                        nop                             '1
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay5                 '5
                        or      outa,mask_scl           '1!     scl high
                        nop                             '1
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

        if_nc           jmp     #shutdown               '1      if sda still not high, shutdown

                        or      dira,mask_sda           '1!     sda low
'
'
' Transmit/receive
'
ee_transmit             shl     eedata,#1               '1      ready to transmit byte and receive ack
                        or      eedata,#%00000000_1     '1
                        jmp     #ee_tr                  '1

ee_receive              mov     eedata,#%11111111_0     '1      ready to receive byte and transmit ack

ee_tr                   mov     bits,#9                 '1      transmit/receive byte and ack
:loop                   test    eedata,#$100    wz      '1      get next sda output state
                        andn    outa,mask_scl           '1!     scl low
                        rcl     eedata,#1               '1      shift in prior sda input state
                        muxz    dira,mask_sda           '1!     sda low/float
                        call    #delay4                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
                        or      outa,mask_scl           '1!     scl high
                        nop                             '1
                        djnz    bits,#:loop             '1,2    if another bit, loop

                        and     eedata,#$FF             '1      isolate byte received
ee_receive_ret
ee_transmit_ret
ee_start_ret            ret                             '1      nc=ack
'
'
' Stop
'
ee_stop                 mov     bits,#9                 '1      ready 9 stop attempts
:loop                   andn    outa,mask_scl           '1!     scl low
                        nop                             '1
                        or      dira,mask_sda           '1!     sda low
                        call    #delay5                 '5
                        or      outa,mask_scl           '1!     scl high
                        call    #delay3                 '3
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay4                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

ee_jmp  if_nc           jmp     #shutdown               '1      if sda still not high, shutdown

ee_stop_ret             ret                             '1
'
'
' Cycle delays
'
delay5                  nop                             '1
delay4                  nop                             '1
delay3                  nop                             '1
delay2
delay2_ret
delay3_ret
delay4_ret
delay5_ret              ret                             '1

'
'
' Constants
'
'mask_rx                 long    $80000000
'mask_tx                 long    $40000000
mask_sda                long    $20000000
mask_scl                long    $10000000
'time                    long    150 * 20000 / 4 / 2     '150ms (@20MHz, 2 inst/loop)
'time_load               long    100 * 20000 / 4 / 2     '100ms (@20MHz, 2 inst/loop)
time_xtal               long    20 * 20000 / 4 / 1      '20ms (@20MHz, 1 inst/loop)
'lfsr                    long    "P"
zero                    long    0
smode                   long    0
'hFFF9FFFF               long    $FFF9FFFF
h8000                   long    $8000
programsize             long    $8000-settings#SettingsSize
interpreter             long    $0001 << 18 + $3C01 << 4 + %0000
'
'
' Variables
'
command                 res     1
address                 res     1
raddress                res     1
count                   res     1
bits                    res     1
eedata                  res     1
'rxdata                  res     1
'delta                   res     1
'threshold               res     1