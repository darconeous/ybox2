{{
        ybox2 - main object
        http://www.deepdarc.com/ybox2

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
  term          : "TV_Text"
  ir            : "ir_reader_sony"
  subsys        : "subsys"
  settings      : "settings"
                                     
VAR
  long weatherstack[40] 
  byte path_holder[64]
DAT
productName   BYTE      "ybox2 weather",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0
  
PUB init | i
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
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
  repeat term#cols
    term.out($90)
  term.out($0c)
  term.out(0)

  subsys.StatusLoading

  if settings.findKey(settings#MISC_STAGE_TWO)
    settings.removeKey(settings#MISC_STAGE_TWO)

  ir.init(15, 0, 300, 1)
         
  if settings.findKey(settings#MISC_SOUND_DISABLE) == FALSE
    dira[subsys#SPKRPin]:=1
  else
    dira[subsys#SPKRPin]:=0

  if NOT settings.findKey(settings#SERVER_PATH)
    if NOT \initial_configuration
      showMessage(string("Server configuration failed!"))
      subsys.StatusFatalError
      SadChirp
      waitcnt(clkfreq*100000 + cnt)
      reboot
  
  dira[0]:=0

  if not \tel.start(1,2,3,4,6,7,-1,-1)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    SadChirp
    waitcnt(clkfreq*10000 + cnt)
    reboot

  HappyChirp

  if settings.getData(settings#NET_MAC_ADDR,@weatherstack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@weatherstack][i],2)
    term.out(13)  

  if NOT settings.getData(settings#NET_IPv4_ADDR,@weatherstack,4)
    term.str(string("Waiting for IP address...",13))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@weatherstack,4)
      delay_ms(500)

  term.str(string("IPv4 ADDR:"))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@weatherstack][i])
  term.out(13)  

  if settings.getData(settings#NET_IPv4_DNS,@weatherstack,4)
    term.str(string("DNS ADDR:"))
    repeat i from 0 to 3
      if i
        term.out(".")
      term.dec(byte[@weatherstack][i])
    term.out(13)  

  if settings.getData(settings#SERVER_IPv4_ADDR,@weatherstack,4)
    term.str(string("SERVER ADDR:"))
    repeat i from 0 to 3
      if i
        term.out(".")
      term.dec(byte[@weatherstack][i])
    term.out(":")  
    term.dec(settings.getWord(settings#SERVER_IPv4_PORT))
    term.out(13)  

  if settings.getString(settings#SERVER_PATH,@weatherstack,40)
    term.str(string("SERVER PATH:'"))
    term.str(@weatherstack)
    term.str(string("'",13))

  if settings.getString(settings#SERVER_HOST,@weatherstack,40)
    term.str(string("SERVER HOST:'"))
    term.str(@weatherstack)
    term.str(string("'",13))
   
  main
PRI initial_configuration
  
  settings.setString(settings#SERVER_HOST,string("propserve.fwdweb.com"))  
  settings.setData(settings#SERVER_IPv4_ADDR,string(208,131,149,67),4)
  settings.setWord(settings#SERVER_IPv4_PORT,80)
  settings.setString(settings#SERVER_PATH,string("/?id=124932&pass=sunplant"))

  return TRUE
  
PUB main | ircode
  delay_ms(2000) ' Wait a second to let the ethernet stabalize

  cognew(WeatherUpdate, @weatherstack) 

  repeat
    \httpServer

  return
  
  repeat while true
    ircode:=ir.fifo_get
    if ircode <> -1
      term.str(string($1,$B,12,$C,$1,"IR CODE: KC="))       
      term.hex(ircode,2)
      term.str(string(" ID="))
      term.hex(ir.fifo_get_lastvalid,4)
      term.str(string($C,$8))       
    if ina[subsys#BTTNPin]
      showMessage(string("BUTTON PRESSED"))    
      subsys.StatusFatalError
      SadChirp
      repeat while ina[subsys#BTTNPin]
      showMessage(string("BUTTON RELEASED"))    
      subsys.StatusIdle
      HappyChirp
    if ircode == $0E
      showMessage(string("Rebooting..."))    
      outa[0]:=0
      dira[0]:=1
      subsys.StatusFatalError
      SadChirp
      reboot
    if ircode == $0F
      term.stop
      term.start(12)
    if ircode == $64
      if settings.findKey(settings#MISC_SOUND_DISABLE) == FALSE
        showMessage(string("[MUTED]"))    
        settings.setByte(settings#MISC_SOUND_DISABLE,TRUE)
        dira[subsys#SPKRPin]:=0       
        ir.fifo_flush
      else
        showMessage(string("[UNMUTED]"))    
        settings.removeKey(settings#MISC_SOUND_DISABLE)
        dira[subsys#SPKRPin]:=1       
        HappyChirp
        ir.fifo_flush
    if ircode == $35
'      ether.wr_phy(ether#PHLCON,%0000_1010_1011_0000)
'      ether.wr_phy(ether#PHCON2,%0100_0000_0000_0000)
    if ircode == $32
'      ether.wr_phy(ether#PHLCON,%0000_1010_1011_0000)
    if ircode == $00
      subsys.StatusLoading
    if ircode == $01
      subsys.StatusIdle
    if ircode == $02
      subsys.StatusFatalError
    

pub WeatherUpdate | timeout, retrydelay, addr, port, gotstart,in
  port := 20000
  retrydelay := 500
  repeat
  
    if port > 30000
      port := 20000

    addr := settings.getLong(settings#SERVER_IPv4_ADDR)
    if tel.connect(@addr,settings.getWord(settings#SERVER_IPv4_PORT),port) == -1
      next
    
    term.str(string($1,$A,39,$C,1," ",$C,$8))
  
    tel.resetBuffers
    
    settings.getString(settings#SERVER_PATH,@path_holder,64)
    tel.waitConnectTimeout(2000)
     
    if NOT tel.isEOF

      term.str(string($1,$B,12,"                                       "))
      term.str(string($1,$A,39,$C,$8," ",$1))
      
      tel.str(string("GET "))
      tel.str(@path_holder)
      tel.str(string(" HTTP/1.0",13,10))       ' use HTTP/1.0, since we don't support chunked encoding
      
      if settings.getString(settings#SERVER_HOST,@path_holder,64)
        tel.str(string("Host: "))
        tel.str(@path_holder)
        tel.str(string(13,10))

      tel.str(string("User-Agent: PropTCP",13,10))
      tel.str(string("Connection: close",13,10,13,10)) 

      gotstart := false
      timeout := cnt
      repeat
        if (in := tel.rxcheck) > 0
 
          if gotstart AND in <> 10
            term.out(in)

          if in == $01
            gotstart := true
        else
          ifnot tel.isConnected
            ' Success!
            retrydelay := 500 ' Reset the retry delay
            subsys.StatusIdle
            term.dec(subsys.RTC) ' Print out the RTC value
            delay_ms(30000)     ' 30 sec delay
            subsys.StatusLoading
            quit
          if cnt-timeout>10*clkfreq ' 10 second timeout      
            subsys.StatusFatalError
            showMessage(string("Error: Connection Lost!"))    
            tel.close
            ++port ' Change the source port, just in case
            if retrydelay < 10_000
               retrydelay+=retrydelay
            delay_ms(retrydelay)             ' failed to connect     
            quit
    else
      subsys.StatusFatalError
      showMessage(string("Error: Failed to Connect!"))    
      tel.close
      ++port ' Change the source port, just in case
      if retrydelay < 10_000
         retrydelay+=retrydelay
      delay_ms(retrydelay)             ' failed to connects     

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
  
OBJ
  http          : "api_telnet_serial"
  base64        : "base64"
VAR
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[160]
  byte httpHeader[32]
  byte buffer[160]
  byte buffer2[160]
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
      repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<126
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
pub httpServer | char, i, lineLength,contentSize,authorized

  repeat
    repeat while \http.listen(80) == -1
      term.str(string("Warning: No free sockets",13))
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(2000)
      http.closeall
      next
    http.resetBuffers
    contentSize:=0
    repeat 100
      if http.isConnected
        quit
      http.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot

    ifnot http.isConnected
      next

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

             
    if strcomp(@httpMethod,string("GET")) or strcomp(@httpMethod,string("POST"))
      if strcomp(@httpPath,string("/"))
        http.str(@HTTP_200)
        http.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,@HTTP_CONTENT_TYPE_HTML)        
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<html><head><title>ybox2</title></head><body><h1>"))
        http.str(@productName)
        http.str(string("</h1><hr />"))
        http.str(string("<h2>Info</h2>"))
        'repeat i from settings#SettingsBottom to settings#SettingsTop-1
        '  http.hex(BYTE[i],2)
        '  http.tx(" ")
        if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
          http.str(string("<div><tt>MAC: "))
          repeat i from 0 to 5
            if i
              http.tx("-")
            http.hex(byte[@httpMethod][i],2)
          http.str(string("</tt></div>"))
        if settings.getData(settings#MISC_UUID,@httpQuery,16)
          http.str(string("<div><tt>UUID: "))
          repeat i from 0 to 3
            http.hex(byte[@httpQuery][i],2)
          http.tx("-")
          repeat i from 4 to 5
            http.hex(byte[@httpQuery][i],2)
          http.tx("-")
          repeat i from 6 to 7
            http.hex(byte[@httpQuery][i],2)
          http.tx("-")
          repeat i from 8 to 9
            http.hex(byte[@httpQuery][i],2)
          http.tx("-")
          repeat i from 10 to 15
            http.hex(byte[@httpQuery][i],2)
          http.str(string("</tt></div>"))
        http.str(string("<div><tt>RTC: "))
        http.dec(subsys.RTC)
        http.str(string("</tt></div>"))
        http.str(string("<div><tt>INA: "))
        repeat i from 0 to 7
          http.dec(ina[i])
        http.tx(" ")
        repeat i from 8 to 15
          http.dec(ina[i])
        http.tx(" ")
        repeat i from 16 to 23
          http.dec(ina[i])
        http.tx(" ")
        repeat i from 23 to 31
          http.dec(ina[i])          
        http.str(string("</tt></div>"))

        http.str(string("<h2>Settings</h2>"))
        http.str(string("<form action='\config' method='PUT'>"))
        http.str(string("<label for='SH'>Server Host</label><input name='SH' id='SH' size='32' value='"))
        settings.getString(settings#SERVER_HOST,@httpQuery,32)
        http.strxml(@httpQuery)
        http.str(string("' /><br />"))
        http.str(string("<label for='SP'>Server Path</label><input name='SP' id='SP' size='32' value='"))
        settings.getString(settings#SERVER_PATH,@httpQuery,32)
        http.strxml(@httpQuery)
        http.str(string("' /><br />"))

        http.str(string("<label for='SA'>Server Address</label><input name='SA' id='SA' size='32' value='"))
        settings.getData(settings#SERVER_IPv4_ADDR,@httpQuery,32)
        http.txip(@httpQuery)
        http.str(string("' /><br />"))

        http.str(string("<input type='submit' />"))
        http.str(string("</form>"))
        
        
        http.str(string("<h2>Actions</h2>"))
        http.str(string("<div><a href='/reboot'>Reboot</a></div>"))
        http.str(string("<h2>Other</h2>"))
        http.str(string("<div><a href='"))
        http.str(@productURL)
        http.str(string("'>More info</a></div>"))

        http.str(string("</body></html>",13,10))
        
      elseif strcomp(@httpPath,string("/config"))
        ifnot authorized
          httpUnauthorized
          next

        if httpGetField(@httpQuery,string("SH"),@buffer,127)
          settings.setString(settings#SERVER_HOST,@buffer)  
        if httpGetField(@httpQuery,string("SP"),@buffer,127)
          settings.setString(settings#SERVER_PATH,@buffer)  

        ' TODO: Server address parsing
        'if httpGetField(@httpQuery,string("SA"),@buffer,127)
        '  settings.setString(settings#SERVER_PATH,@buffer)  
        

        http.str(@HTTP_303)
        http.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("OK",13,10))

      elseif strcomp(@httpPath,string("/reboot"))
        ifnot authorized
          httpUnauthorized
          next
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("REBOOTING",13,10))
        http.close
        reboot
      else           
        httpNotFound
    else
        http.str(@HTTP_501)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(@HTTP_501)
    
    http.close
 