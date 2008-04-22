{{
        ybox2 - bootloader object
        http://www.deepdarc.com/ybox2

        Designed for use with a 64KB EEPROM. It will not work
        properly with a 32KB EEPROM.

        See the method 'initial_configuration' to change settings
        like the MAC address, IP address, server address, etc.

        If your pin assignments are different, you'll need to
        change them here and in the subsys object.

}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      

OBJ

  tel           : "api_telnet_serial"
  http          : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  eeprom        : "Basic_I2C_Driver"
  random        : "RealRandom"
  base64        : "base64"                                   
VAR
  long stack[80] 
  byte stage_two
DAT
productName   BYTE      "ybox2 bootloader v0.5",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0

PUB init | i
  'cognew(@bootstage2,0)
  'return
  
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
  webCog:=0

  settings.start
  
  subsys.init
  term.start(12)
  term.str(string($0C,7))
  term.str(@productName)
  term.out(13)
  term.str(@productURL)
  term.out(13)
  term.out($0c)
  term.out(2)
  repeat term#cols/2
    term.out($8E)
    term.out($88)
  term.out($0c)
  term.out(0)
  
  subsys.StatusLoading


  if settings.findKey(settings#MISC_STAGE_TWO)
    stage_two := TRUE
    settings.removeKey(settings#MISC_STAGE_TWO)
  else
    stage_two := FALSE

  if NOT stage_two AND settings.findKey(settings#MISC_AUTOBOOT)
    delay_ms(2000)
    if NOT ina[subsys#BTTNPin]
      boot_stage2
    else
      term.str(string("Autoboot Aborted.",13))
      SadChirp    

  if NOT settings.size
    if NOT \initial_configuration
      term.str(string("Initial configuration failed!",13))
      subsys.StatusFatalError
      SadChirp
      waitcnt(clkfreq*100000 + cnt)
      reboot

  if settings.getData(settings#NET_MAC_ADDR,@stack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@stack][i],2)
    term.out(13)  
  
  dira[0]:=0

  if settings.findKey(settings#MISC_SOUND_DISABLE) == FALSE
    dira[subsys#SPKRPin]:=1
  else
    dira[subsys#SPKRPin]:=0

  ' If the user is holding down the button, wait two seconds.
  repeat 10
    if ina[subsys#BTTNPin]
      delay_ms(200)
    
  ' If the button is still being held down, then
  ' assume we are in a password reset condition.
  if ina[subsys#BTTNPin]
    HappyChirp
    SadChirp
    HappyChirp
    SadChirp
    HappyChirp
    if ina[subsys#BTTNPin]
      term.str(string("RESET MODE",13))
      SadChirp
      settings.removeKey(settings#MISC_PASSWORD)  
      settings.removeKey(settings#MISC_AUTOBOOT)
      settings.removeKey(settings#NET_DHCPv4_DISABLE)
      settings.removeKey(settings#MISC_SOUND_DISABLE)
      settings.removeKey($1010)
      settings.removeKey(settings#MISC_STAGE_TWO)
      settings.commit
      HappyChirp
      reboot

  if not \tel.start(1,2,3,4,6,7,-1,-1)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    SadChirp
    waitcnt(clkfreq*10000 + cnt)
    reboot

  HappyChirp

  if NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
    term.str(string("IPv4 ADDR: DHCP..."))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
      delay_ms(500)
  term.out($0A)
  term.out($00)  
  term.str(string("IPv4 ADDR: "))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@stack][i])
  term.out(13)  

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

  'settings.setString(settings#MISC_PASSWORD,string("admin:password"))  
  'settings.removeKey(settings#MISC_PASSWORD)  
      
  repeat
    \httpServer
  
PRI boot_stage2 | i
  settings.setByte(settings#MISC_STAGE_TWO,TRUE)
  repeat i from 0 to 7
    if cogid<>i
      cogstop(i)
  ' Replace this cog with the bootloader
  coginit(0,@bootstage2,0)
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

  'settings.setString(settings#MISC_PASSWORD,string("admin:password"))  

  
  ' Uncomment and change these settings if you don't want to use DHCP
  {
  settings.setByte(settings#NET_DHCPv4_DISABLE,TRUE)
  settings.setData(settings#NET_IPv4_ADDR,string(192,168,2,10),4)
  settings.setData(settings#NET_IPv4_MASK,string(255,255,255,0),4)
  settings.setData(settings#NET_IPv4_GATE,string(192,168,2,1),4)
  settings.setData(settings#NET_IPv4_DNS,string(4,2,2,4),4)
  }

  ' If you want sound off by default, uncomment the next line
  'settings.setByte(settings#MISC_SOUND_DISABLE,TRUE)

  'settings.setByte(settings#MISC_AUTOBOOT,TRUE)

  ' RGB LED Configuration
  ' Original board = $000A0B09
  ' Adafruit board = $01090A0B (This is the default)
  'settings.setLong(settings#MISC_LED_CONF,$01090A0B)
  'settings.setLong(settings#MISC_LED_CONF,$000A0B09)

  settings.commit
  return TRUE

  
VAR
  byte buffer [128]
  byte buffer2 [128]
  byte webCog
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

pri httpOutputLink(url,content)
  http.str(string("<a href='"))
  http.strxml(url)
  http.str(string("'>"))
  http.str(content)
  http.str(string("</a>"))
  
pri httpParseRequest(method,path,query) | i,char
    i:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<7
      BYTE[method][i]:=char
      if char == " "
        quit
      i++
    BYTE[method][i]:=0
    i:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<63
      BYTE[path][i]:=char
      if char == " " OR char == "?"  OR char == "#"
        quit
      i++

    if BYTE[path][i]=="?"
      ' If we stopped on a question mark, then grab the query
      BYTE[path][i]:=0
      i:=0
      repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<63
        BYTE[query][i]:=char
        if char == " " OR char == "#" OR char == 13
          quit
        i++        
      BYTE[query][i]:=0
    else
      BYTE[path][i]:=0
      BYTE[query][0]:=0

pri httpUnauthorized
  http.str(@HTTP_401)
  http.str(@HTTP_CONNECTION_CLOSE)
  http.txMimeHeader(string("WWW-Authenticate"),string("Basic realm='ybox2'"))
  http.str(@CR_LF)
  http.str(@HTTP_401)

pri httpNotFound
  http.str(@HTTP_404)
  http.str(@HTTP_CONNECTION_CLOSE)
  http.str(@CR_LF)
  http.str(@HTTP_404)
pri httpGetField(packeddataptr,keystring,outvalue,outsize) | i,char
  i:=0
  repeat while BYTE[packeddataptr]
    if BYTE[packeddataptr]=="=" 'AND strsize(keystring)==i
      packeddataptr++
      i:=0
      repeat while byte[packeddataptr] AND byte[packeddataptr]<>"&" AND i<outsize-2
         BYTE[outvalue][i++]:=byte[packeddataptr++]
      BYTE[outvalue][i]:=0
      httpURLUnescapeInplace(outvalue)
      return i
    if BYTE[packeddataptr] <> BYTE[keystring][i]
      ' skip to &
      repeat while byte[packeddataptr] AND byte[packeddataptr]<>"&"
        packeddataptr++
      ifnot byte[packeddataptr] 
        quit
      packeddataptr++
      i:=0
    else
      packeddataptr++
      i++  
  return 0

pri httpURLUnescapeInplace(in_ptr) | out_ptr,char,val
  out_ptr:=in_ptr
  repeat while (char:=byte[in_ptr++])
    if char=="%"
      case (char:=byte[in_ptr++])
        "a".."f": val:=char-"a"+10
        "A".."F": val:=char-"A"+10
        "0".."9": val:=char-"0"
        0: quit
        other: next
      val:=val<<4
      case (char:=byte[in_ptr++])
        "a".."f": val|=char-"a"+10
        "A".."F": val|=char-"A"+10
        "0".."9": val|=char-"0"
        0: quit
        other: next
      char:=val
    byte[out_ptr++]:=char
  byte[out_ptr++]:=0
  return TRUE
           

     
pub httpServer | char, i,j, lineLength,contentSize,authorized
  webCog:=cogid+1

  repeat
    repeat while \http.listen(80) == -1
      term.str(string("No free sockets",13))
      if ina[subsys#BTTNPin]
        boot_stage2
      delay_ms(2000)
      http.closeall
      next
    http.resetBuffers
    contentSize:=0
    repeat while NOT http.isConnected
      http.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        boot_stage2

    httpParseRequest(@httpMethod,@httpPath,@httpQuery)

    ' If there isn't a password set, then we are by default "authorized"
    authorized:=NOT settings.findKey(settings#MISC_PASSWORD)
    
    lineLength:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF)
      if (char == 13)
        char:=http.rxtime(1000)
      if (char == 10)
        ifnot lineLength
          quit
        lineLength:=0
      else
        if lineLength<31
          httpHeader[lineLength++]:=char
          if char == ":"
            httpHeader[lineLength-1]:=0
            if strcomp(@httpHeader,@HTTP_HEADER_CONTENT_LENGTH)
              contentSize := http.readDec
            elseif NOT authorized AND strcomp(@httpHeader,string("Authorization"))
              http.rxtime(1000)
              repeat i from 0 to 7 ' Skip the 'Basic' part
                if http.rxtime(1000) == " " OR http.isEOF
                  quit
              i:=0
              repeat while i<127 AND ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF)
                buffer[i++]:=char
                if (char == 13)
                  quit
              if i
                buffer[i]:=0
                base64.inplaceDecode(@buffer)  
                settings.getString(settings#MISC_PASSWORD,@buffer2,127)
                authorized:=strcomp(@buffer,@buffer2)
            httpHeader[0]:=0

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
        http.str(@HTTP_200)
        http.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,@HTTP_CONTENT_TYPE_HTML)        
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<html><body><h1>"))
        http.str(@productName)
        http.str(string("</h1><hr />"))
        http.str(string("<h2>Info</h2>"))
        if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
          http.str(string("<div><tt>MAC: "))
          repeat i from 0 to 5
            if i
              http.tx("-")
            http.hex(byte[@httpMethod][i],2)
          http.str(string("</tt></div>"))
        if settings.getData(settings#MISC_UUID,@httpMethod,16)
          http.str(string("<div><tt>UUID: "))
          repeat i from 0 to 3
            http.hex(byte[@httpMethod][i],2)
          http.tx("-")
          repeat i from 4 to 5
            http.hex(byte[@httpMethod][i],2)
          http.tx("-")
          repeat i from 6 to 7
            http.hex(byte[@httpMethod][i],2)
          http.tx("-")
          repeat i from 8 to 9
            http.hex(byte[@httpMethod][i],2)
          http.tx("-")
          repeat i from 10 to 15
            http.hex(byte[@httpMethod][i],2)
          http.str(string("</tt></div>"))
        http.str(string("<div><tt>RTC: "))
        http.dec(subsys.RTC)
        http.str(string("</tt></div>"))

        http.str(string("<div><tt>Autoboot: "))
        if settings.findKey(settings#MISC_AUTOBOOT)  
          http.str(string("<b>ON</b> "))
          if authorized
            httpOutputLink(string("/autoboot?0"),string("disable"))
        else
          http.str(string("<b>OFF</b> "))
          if authorized
            httpOutputLink(string("/autoboot?1"),string("enable"))
        http.str(string("</tt></div>"))

        http.str(string("<div><tt>Password: "))
        if settings.findKey(settings#MISC_PASSWORD)
          http.str(string("SET"))  
        else
          http.str(string("NOT SET"))  
        http.str(string("</tt></div>"))


        if authorized
          http.str(string("<form action='\password' method='POST'>"))
          http.str(string("<div><label for='username'>Username:</label><input name='username' id='username' size='32' value='"))
          http.strxml(string("admin"))
          http.str(string("' /></div>"))
          http.str(string("<div><label for='pwd1'>Password:</label><input name='pwd1' id='pwd1' type='password' size='32' /></div>"))
          http.str(string("<div><label for='pwd2'>Password:</label><input name='pwd2' id='pwd2' type='password' size='32' /></div>"))
           
          http.str(string("<input type='submit' />"))
          http.str(string("</form>"))
           


        
        http.str(string("<h2>Actions</h2>"))
        http.str(string("<div>"))
        httpOutputLink(string("/reboot"),string("Reboot"))
        http.tx(" ")
        httpOutputLink(string("/stage2"),string("Boot stage 2"))
        ifnot authorized
          http.tx(" ")
          httpOutputLink(string("/login"),string("Login"))
        http.str(string("</div>"))
        

        http.str(string("<h2>Files</h2>"))
        http.str(string("<div>"))
        httpOutputLink(@RAMIMAGE_EEPROM_FILE,@RAMIMAGE_EEPROM_FILE+1)
        http.tx(" ")
        httpOutputLink(@STAGE2_EEPROM_FILE,@STAGE2_EEPROM_FILE+1)
        http.tx(" ")
        httpOutputLink(@CONFIG_BIN_FILE,@CONFIG_BIN_FILE+1)
        http.str(string("</div>"))

        http.str(string("<h2>Other</h2>"))
        http.str(string("<div>"))
        httpOutputLink(@productURL,@productURL)
        http.str(string("</div>"))
        http.str(string("</body></html>",13,10))
        
      elseif strcomp(@httpPath,string("/password"))
        ifnot authorized
          httpUnauthorized
          next
        i:=0
        repeat while contentSize AND i<127
          char:=http.rxtime(1000)
          buffer[i++]:=char
          contentSize--
        buffer[i]:=0
        buffer2[0]:=0
        i:=httpGetField(@buffer,string("username"),@buffer2,127)
        if i
          buffer2[i++]:=":"
          j:=httpGetField(@buffer,string("pwd1"),@buffer2+i,63)
          ifnot j
             i:=0
          else
            j:=httpGetField(@buffer,string("pwd2"),@httpQuery,63)
          if j==0 OR NOT strcomp(@httpQuery,@buffer2+i)
            i:=0
         
        ifnot i
          http.str(string("HTTP/1.1 400 Bad Request",13,10))
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(string("Passwords didn't match.",13,10))
        else
          settings.removeKey($1010)
          settings.setString(settings#MISC_PASSWORD,@buffer2)  
          settings.commit
           
          http.str(@HTTP_303)
          http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/reboot"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("REBOOTING",13,10))
        http.close
        reboot
      elseif strcomp(@httpPath,string("/stage2"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("BOOTING STAGE 2",13,10))
        http.close
        boot_stage2
      elseif strcomp(@httpPath,string("/login"))
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_303)
        http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/ledconfig"))
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        if httpQuery[0]=="1"
          settings.removeKey($1010)
          settings.setLong(settings#MISC_LED_CONF,$000A0B09)
          settings.commit
          http.str(string("ENABLED (NEEDS REBOOT)",13,10))
        else
          settings.removeKey($1010)
          settings.removeKey(settings#MISC_LED_CONF)
          settings.commit
          http.str(string("DISABLED (NEEDS REBOOT)",13,10))
      elseif strcomp(@httpPath,string("/autoboot"))
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_303)
        http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        if httpQuery[0]=="1"
          settings.removeKey($1010)
          settings.setByte(settings#MISC_AUTOBOOT,1)
          settings.commit
          http.str(string("ENABLED",13,10))
        else
          settings.removeKey($1010)
          settings.removeKey(settings#MISC_AUTOBOOT)
          settings.commit
          http.str(string("DISABLED",13,10))
      elseif strcomp(@httpPath,RAMIMAGE_EEPROM_FILE)
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-eeprom"))        
        http.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=ramimage.eeprom"))        
        http.txmimeheader(@HTTP_HEADER_CONTENT_LENGTH,string("32768"))        
        http.str(@CR_LF)
        repeat i from 0 to $7FFF
          http.tx(BYTE[i])
      elseif strcomp(@httpPath,STAGE2_EEPROM_FILE)
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-eeprom"))        
        http.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=stage2.eeprom"))        
        http.txmimeheader(@HTTP_HEADER_CONTENT_LENGTH,string("32768"))        
        http.str(@CR_LF)
        repeat i from 0 to $7FFF step 128
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
            quit
          repeat j from 0 to 127
            http.tx(buffer[j])
      elseif strcomp(@httpPath,@CONFIG_BIN_FILE)
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,string("application/x-bin"))        
        http.txmimeheader(@HTTP_HEADER_CONTENT_DISPOS,string("attachment; filename=config.bin"))        
        http.str(@HTTP_HEADER_CONTENT_LENGTH)
        http.str(string(": "))
        http.dec(settings#SettingsSize)
        http.str(@CR_LF)        
        http.str(@CR_LF)
        repeat i from settings#SettingsBottom to settings#SettingsTop step 128
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
            quit
          repeat j from 0 to 127
            http.tx(buffer[j])
      else           
        httpNotFound
    elseif strcomp(@httpMethod,string("PUT"))
      ifnot authorized
        httpUnauthorized
        next
      if not contentSize
          http.str(@HTTP_411)
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(@HTTP_411)
      if strcomp(@httpPath,@RAMIMAGE_EEPROM_FILE) OR strcomp(@httpPath,@CONFIG_BIN_FILE)
        http.str(@HTTP_403)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(@HTTP_403)
      elseif strcomp(@httpPath,@STAGE2_EEPROM_FILE)
        if (i:=\downloadFirmwareHTTP(contentSize))
          SadChirp
          subsys.StatusFatalError
          http.str(string("HTTP/1.1 400 Bad Request",13,10))
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(string("Upload Failure",13,10))
          http.dec(i)         
          http.str(@CR_LF)
        else
          if strcomp(@httpQuery,string("boot")) OR stage_two
            http.str(@HTTP_303)
            http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
            http.str(@HTTP_CONNECTION_CLOSE)
            http.str(@CR_LF)
            if stage_two
              http.str(string("OK - Rebooting",13,10))
              http.close
              reboot
            else
              http.str(string("OK - Booting stage 2",13,10))
              http.close
              boot_stage2
          else
            http.str(@HTTP_303)
            http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
            http.str(@HTTP_CONNECTION_CLOSE)
            http.str(@CR_LF)
            http.str(string("OK",13,10))
      else
        httpNotFound
    else
      http.str(@HTTP_501)
      http.str(@HTTP_CONNECTION_CLOSE)
      http.str(@CR_LF)
      http.str(@HTTP_501)
    
    http.close


pub downloadFirmwareHTTP(contentSize) | timeout, retrydelay,in, i, total, addr,j
  eeprom.Initialize(eeprom#BootPin)

  i:=0
  total:=0
  
  if stage_two
    addr:=$0000 ' Stage two writes to the lower 32KB
  else
    addr:=$8000 ' Stage one writes to the upper 32KB

  if contentSize > $8000-settings#SettingsSize
    contentSize:=$8000-settings#SettingsSize
   
  repeat
    if (in := http.rxcheck) => 0
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
        http.close
    else
      subsys.StatusSolid(128,0,0)
      if http.isEOF OR (total+i) => contentSize
        if stage_two
          ' Do we have the correct number of bytes?
          if settings.findKey($1010) AND ((total+i) <> settings.getWord($1010))
            SadChirp
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
          HappyChirp

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
        HappyChirp
        subsys.StatusSolid(0,255,0)
        settings.setWord($1010,total)
        return 0


  return 0

PUB showMessage(str)
  term.str(string($1,$B,12,$C,$1))    
  term.str(str)    
  term.str(string($C,$8))    

pub HappyChirp | i, j
  repeat j from 0 to 2
    repeat i from 0 to 30
      outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
      delay_ms(1)
    outa[subsys#SPKRPin]:=0  
    delay_ms(50)
pub SadChirp | i

  repeat i from 0 to 15
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    delay_ms(17)
  outa[subsys#SPKRPin]:=0  

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
mask_rx                 long    $80000000
mask_tx                 long    $40000000
mask_sda                long    $20000000
mask_scl                long    $10000000
time                    long    150 * 20000 / 4 / 2     '150ms (@20MHz, 2 inst/loop)
time_load               long    100 * 20000 / 4 / 2     '100ms (@20MHz, 2 inst/loop)
time_xtal               long    20 * 20000 / 4 / 1      '20ms (@20MHz, 1 inst/loop)
lfsr                    long    "P"
zero                    long    0
smode                   long    0
hFFF9FFFF               long    $FFF9FFFF
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
rxdata                  res     1
delta                   res     1
threshold               res     1