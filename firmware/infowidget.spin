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

  websocket     : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  http          : "http"
  base64        : "base64"
  tel           : "api_telnet_serial"
                                     
VAR
  byte path_holder[128]
  byte tv_mode

  ' Statistics
  long stat_refreshes
  long stat_errors

  long weatherstack[200]  
DAT
productName   BYTE      "ybox2 info widget",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0
  
PUB init | i
  dira[0]:=1 ' Set direction on reset pin
  outa[0]:=0 ' Set state on reset pin to LOW
  dira[subsys#SPKRPin]:=1

  stat_refreshes:=0
  stat_errors:=0

  ' Default to NTSC
  tv_mode:=term#MODE_NTSC
  
  settings.start
  subsys.init

  ' If there is a TV mode preference in the EEPROM, load it up.
  if settings.findKey(settings#MISC_TV_MODE)
    tv_mode := settings.getByte(settings#MISC_TV_MODE)
    
  ' Start the TV Terminal
  term.startWithMode(12,tv_mode)

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

  if settings.findKey(settings#MISC_STAGE2)
    settings.removeKey(settings#MISC_STAGE2)

  'ir.init(15, 0, 300, 1)
         
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
  
  outa[0]:=1 ' Pull ethernet reset pin high, ending the reset condition.
  if not \tel.start(1,2,3,4,6,7,-1,-1)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    SadChirp
    waitcnt(clkfreq*10000 + cnt)
    reboot

  if settings.getData(settings#NET_MAC_ADDR,@weatherstack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@weatherstack][i],2)
    term.out(13)  

  if NOT settings.getData(settings#NET_IPv4_ADDR,@weatherstack,4)
    term.str(string("IPv4 ADDR: DHCP..."))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@weatherstack,4)
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(500)
  term.out($0A)
  term.out($00)  
  term.str(string("IPv4 ADDR: "))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@weatherstack][i])
  term.out(13)  


  if settings.getData(settings#NET_IPv4_DNS,@weatherstack,4)
    term.str(string("DNS ADDR: "))
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
   

  cognew(WeatherCog, @weatherstack) 

  repeat
    HappyChirp
    i:=\httpServer
    term.out("[")
    term.dec(i)
    term.out("]")
     
    subsys.StatusFatalError
    SadChirp
    delay_ms(500)
    websocket.closeAll
  reboot

PRI initial_configuration

  settings.setString(settings#SERVER_HOST,string("propserve.fwdweb.com"))  
  settings.setData(settings#SERVER_IPv4_ADDR,string(208,131,149,67),4)
  settings.setWord(settings#SERVER_IPv4_PORT,80)
  settings.setString(settings#SERVER_PATH,string("/?zipcode=95008"))
{
  settings.setString(settings#SERVER_HOST,string("www.deepdarc.com"))  
  settings.setData(settings#SERVER_IPv4_ADDR,string(69,73,181,158),4)
  settings.setWord(settings#SERVER_IPv4_PORT,80)
  settings.setString(settings#SERVER_PATH,string("/weather.php?zip=95008"))
}
  return TRUE
  
{{
PUB main
  'delay_ms(1000) ' Wait a second to let the ethernet stabalize

  'cognew(WeatherUpdate, @weatherstack) 
  'repeat
  'delay_ms(5000) ' Wait a second to let the ethernet stabalize
  
  \httpServer

  subsys.StatusFatalError
  SadChirp
  reboot
    
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
}}    

pub WeatherCog | retrydelay,port,err
  port := 20000

  repeat
    subsys.StatusLoading
    if (err:=\WeatherUpdate(port))
      retrydelay := 500 ' Reset the retry delay
      subsys.StatusIdle
      term.str(string($B,12))    
      term.dec(subsys.RTC) ' Print out the RTC value
      term.out(" ")
      tel.close
      delay_ms(30000)     ' 30 sec delay
    else
      subsys.StatusErrorCode(err)
      stat_errors++
      showMessage(string("Error!"))    
      tel.closeall
      websocket.closeall
      if retrydelay < 10_000
         retrydelay+=retrydelay
      delay_ms(retrydelay)             ' failed to connect     
    if ++port > 30000
      port := 20000
       

pub WeatherUpdate(port) | timeout, addr, gotstart,in,i
  if settings.getString(settings#SERVER_PATH,@path_holder,64)=<0
    abort 5
   
  addr := settings.getLong(settings#SERVER_IPv4_ADDR)
  if tel.connect(@addr,settings.getWord(settings#SERVER_IPv4_PORT),port) == -1
    abort 6
   
  term.str(string($1,$A,39,$C,1," ",$C,$8,$1,$B))
  term.out(0)
   
  tel.waitConnectTimeout(2000)
   
  ifnot tel.isEOF
    stat_refreshes++
   
    term.str(string($1,$B,12,"                                       "))
    term.str(string($1,$A,39,$C,$8," ",$1))
    
    tel.str(string("GET "))
    tel.str(@path_holder)
    tel.str(string(" HTTP/1.0",13,10))       ' use HTTP/1.0, since we don't support chunked encoding
    
    if settings.getString(settings#SERVER_HOST,@path_holder,64)
      tel.txmimeheader(string("Host"),@path_holder)
   
    tel.txmimeheader(string("User-Agent"),string("PropTCP"))
    tel.txmimeheader(string("Connection"),string("close"))
    tel.str(@CR_LF)
   
    repeat while \http.getNextHeader(tel.handle,0,0,0,0)>0
        
    timeout := cnt
    i:=0
    repeat
      if (in := tel.rxcheck) > 0
        if in <> 10
          term.out(in)
          i++
      else
        ifnot tel.isConnected
          return NOT i
        if cnt-timeout>10*clkfreq ' 10 second timeout      
          abort(subsys#ERR_DISCONNECTED)
  else
    abort(subsys#ERR_NO_CONNECT)
  return 666
     
PUB showMessage(str)
  term.str(string($1,$B,12,$C,$1))    
  term.str(str)    
  term.str(string($C,$8))    

pub HappyChirp
  subsys.chirpHappy
pub SadChirp
  subsys.chirpSad
    
PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
VAR
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[64]
  byte httpHeader[32]
  byte buffer[128]
  byte buffer2[128]
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

pri parseIPStr(instr,outaddr) | char, i,j
  repeat j from 0 to 3
    BYTE[outaddr][j]:=0
  j:=0
  repeat while j < 4
    case BYTE[instr]
      "0".."9":
        BYTE[outaddr][j]:=BYTE[outaddr][j]*10+BYTE[instr]-"0"
      ".":
        j++
      other:
        quit
    instr++
  if j==3
    return TRUE
  abort FALSE 
      
PUB atoi(inptr):retVal | i,char
  retVal~
  
  ' Skip leading whitespace
  repeat while BYTE[inptr] AND BYTE[inptr]==" "
    inptr++
   
  repeat 10
    case (char := BYTE[inptr++])
      "0".."9":
        retVal:=retVal*10+char-"0"
      OTHER:
        quit
         
pub addTextField(id,label,value,length)
  websocket.str(string("<div><label for='"))
  websocket.str(id)
  websocket.str(string("'>"))
  websocket.str(label)
  websocket.str(string(":</label><br /><input name='"))
  websocket.str(id)
  websocket.str(string("' id='"))
  websocket.str(id)
  websocket.str(string("' size='"))
  websocket.dec(length)
  websocket.str(string("' value='"))
  websocket.strxml(value)
  websocket.str(string("' /></div>"))

pub httpServer | i, contentLength,authorized
  repeat
    repeat while websocket.listen(80) < 0
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(1000)
      websocket.closeall
      next
    
    repeat while NOT websocket.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot

    ' If there isn't a password set, then we are by default "authorized"
    authorized:=NOT settings.findKey(settings#MISC_PASSWORD)
    contentLength:=0

    if \http.parseRequest(websocket.handle,@httpMethod,@httpPath,@httpQuery)<0
      websocket.close
      next
        
    repeat while \http.getNextHeader(websocket.handle,@httpHeader,32,@buffer,128)>0
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

             
    if strcomp(@httpMethod,string("GET")) or strcomp(@httpMethod,string("POST"))
      if strcomp(@httpPath,string("/"))
        websocket.str(@HTTP_200)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,@HTTP_CONTENT_TYPE_HTML)        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)

        websocket.str(string("<html><head><meta name='viewport' content='width=320' /><title>ybox2</title>"))
        websocket.str(string("<link rel='stylesheet' href='http://www.deepdarc.com/iphone/iPhoneButtons.css' />"))
 
        websocket.str(string("</head><body><h1>"))
        websocket.str(@productName)
        websocket.str(string("</h1>"))

        if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
          websocket.str(string("<div><tt>MAC: "))
          repeat i from 0 to 5
            if i
              websocket.tx("-")
            websocket.hex(byte[@httpMethod][i],2)
          websocket.str(string("</tt></div>"))

        websocket.str(string("<div><tt>Uptime: "))
        websocket.dec(subsys.RTC/60)
        websocket.tx("m")
        websocket.dec(subsys.RTC//60)
        websocket.tx("s")
        websocket.str(string("</tt></div>"))
        websocket.str(string("<div><tt>Refreshes: "))
        websocket.dec(stat_refreshes)
        websocket.str(string("</tt></div>"))
        websocket.str(string("<div><tt>Errors: "))
        websocket.dec(stat_errors)
        websocket.str(string("</tt></div>"))
        websocket.str(string("<div><tt>INA: "))
        repeat i from 0 to 7
          websocket.dec(ina[i])
        websocket.tx(" ")
        repeat i from 8 to 15
          websocket.dec(ina[i])
        websocket.tx(" ")
        repeat i from 16 to 23
          websocket.dec(ina[i])
        websocket.tx(" ")
        repeat i from 23 to 31
          websocket.dec(ina[i])          
        websocket.str(string("</tt></div>"))

        websocket.str(string("<h2>Settings</h2>"))
        websocket.str(string("<form action='\config' method='PUT'>"))
        settings.getString(settings#SERVER_HOST,@httpQuery,32)
        addTextField(string("SH"),string("Server Host"),@httpQuery,32)
        settings.getString(settings#SERVER_Path,@httpQuery,32)
        addTextField(string("SP"),string("Server Path"),@httpQuery,32)

        websocket.str(string("<label for='SA'>Server Address</label><br /><input name='SA' id='SA' size='32' value='"))
        settings.getData(settings#SERVER_IPv4_ADDR,@httpQuery,32)
        websocket.txip(@httpQuery)
        websocket.str(string("' /><br />"))

        websocket.str(string("<input name='submit' type='submit' />"))
        websocket.str(string("</form>"))
        
        
        websocket.str(string("<h2>Actions</h2>"))
        websocket.str(string("<div><a href='/reboot'>Reboot</a></div>"))
        websocket.str(string("<h2>Other</h2>"))
        websocket.str(string("<div><a href='"))
        websocket.str(@productURL)
        websocket.str(string("'>More info</a></div>"))

        websocket.str(string("</body></html>",13,10))
        
      elseif strcomp(@httpPath,string("/config"))
        ifnot authorized
          httpUnauthorized
          next

        if http.getFieldFromQuery(@httpQuery,string("SH"),@buffer,127)
          settings.setString(settings#SERVER_HOST,@buffer)  
        if http.getFieldFromQuery(@httpQuery,string("SP"),@buffer,127)
          settings.setString(settings#SERVER_PATH,@buffer)  

        if http.getFieldFromQuery(@httpQuery,string("SA"),@buffer,127)
          parseIPStr(@buffer,@buffer2)
          settings.setData(settings#SERVER_IPv4_ADDR,@buffer2,4)  
        
        settings.removeKey($1010)
        settings.removeKey(settings#MISC_STAGE2)
        settings.commit
        
        websocket.str(@HTTP_303)
        websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("OK",13,10))

      elseif strcomp(@httpPath,string("/reboot"))
        ifnot authorized
          httpUnauthorized
          next
        websocket.str(@HTTP_200)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("REBOOTING",13,10))
        websocket.close
        reboot
      else           
        httpNotFound
    else
        websocket.str(@HTTP_501)
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(@HTTP_501)
    
    websocket.close
 