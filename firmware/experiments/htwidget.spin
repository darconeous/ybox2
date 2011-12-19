{{
        ybox2 - Home Theater Integration Widget
        http://www.deepdarc.com/ybox2

        ABOUT

        This widget will allow you to control a Sony TV
        from the network, and could easily be extended
        to support additional TV models.
}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  X10_ZC_PIN = 26
  X10_IN_PIN = 25
  X10_OUT_PIN = 24
  IR_PIN   = 27
  
OBJ

  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  numbers       : "numbers"
  socket        : "api_telnet_serial"
  http          : "http"
  base64        : "base64"
  auth          : "auth_digest"
  sony_out      : "ir_transmit_sony"
  pause : "pause"
  X10           : "X10"
                              
VAR
  long stack[100] 
  byte stage_two
  byte tv_mode
  long hits
  
DAT                      
productName   BYTE      "ybox2 Home Theater",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0

PUB init | i
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
  ' Default to NTSC
  tv_mode:=term#MODE_NTSC
  
  hits:=0
  settings.start
  numbers.init
  sony_out.init(IR_PIN)
  
  ' If you aren't using this thru the bootloader, set your
  ' settings here. 
  {
  settings.setData(settings#NET_MAC_ADDR,string(02,01,01,01,01,01),6)  
  settings.setLong(settings#MISC_LED_CONF,$010B0A09)
  settings.setByte(settings#NET_DHCPv4_DISABLE,TRUE)
  settings.setData(settings#NET_IPv4_ADDR,string(192,168,2,10),4)
  settings.setData(settings#NET_IPv4_MASK,string(255,255,255,0),4)
  settings.setData(settings#NET_IPv4_GATE,string(192,168,2,1),4)
  settings.setData(settings#NET_IPv4_DNS,string(4,2,2,4),4)
  settings.setByte(settings#MISC_SOUND_DISABLE,TRUE)
  }

  settings.removeKey(settings#MISC_STAGE2)
  
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
  repeat term#cols/2
    term.out($8E)
    term.out($88)
  term.out($0c)
  term.out(0)
  
  subsys.StatusLoading

  if settings.getData(settings#NET_MAC_ADDR,@stack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@stack][i],2)
    term.out(13)  

  dira[subsys#SPKRPin]:=!settings.findKey(settings#MISC_SOUND_DISABLE)
  
  dira[0]:=0
  if not \socket.start(1,2,3,4,6,7)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    subsys.chirpSad
    waitcnt(clkfreq*10000 + cnt)
    reboot

  if NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
    term.str(string("IPv4 ADDR: DHCP..."))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
      if ina[subsys#BTTNPin]
        reboot
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

  subsys.StatusIdle
  subsys.chirpHappy

  if(!settings.findKey(settings#MISC_X10_HOUSE))
    ' By default, use house 'H'
    settings.setByte(settings#MISC_X10_HOUSE,X10#HOUSE_H)

  X10.start(X10_ZC_PIN,X10_IN_PIN,X10_OUT_PIN)
 
  repeat
    i:=\httpServer
    subsys.click
    term.str(string("HTTP SERVER EXCEPTION "))
    term.dec(i)
    term.out(13)
    socket.closeall
    
PUB showMessage(str)
  term.str(string($1,$B,12,$C,$1))    
  term.str(str)    
  term.str(string($C,$8))    

PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
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
HTTP_411      BYTE      "HTTP/1.1 411 Length Required",13,10,0
HTTP_501      BYTE      "HTTP/1.1 501 Not Implemented",13,10,0
HTTP_401      BYTE      "HTTP/1.1 401 Authorization Required",13,10,0

HTTP_CONTENT_TYPE_HTML  BYTE "Content-Type: text/html; charset=utf-8",13,10,0
HTTP_CONNECTION_CLOSE   BYTE "Connection: close",13,10,0
pri httpUnauthorized(authorized)
  socket.str(@HTTP_401)
  socket.str(@HTTP_CONNECTION_CLOSE)
  auth.generateChallenge(@buffer,127,authorized)
  socket.txMimeHeader(string("WWW-Authenticate"),@buffer)
  socket.str(@CR_LF)
  socket.str(@HTTP_401)

pub httpServer | char, i, contentLength,authorized,queryPtr, tmp1, tmp2, tmp3, house,code,unit

  repeat
    repeat while \socket.listen(80) == -1
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(100)
      socket.closeall
      next

    repeat while NOT socket.isConnected
      socket.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot

    ' If there isn't a password set, then we are by default "authorized"
    authorized:=NOT settings.findKey(settings#MISC_PASSWORD)
    
    http.parseRequest(socket.handle,@httpMethod,@httpPath)
    
    contentLength:=0
    repeat while http.getNextHeader(socket.handle,@httpHeader,32,@buffer,256)
      if strcomp(@httpHeader,string("Content-Length"))
        contentLength:=numbers.fromStr(@buffer,numbers#DEC)
      elseif NOT authorized AND strcomp(@httpHeader,string("Authorization"))
        authorized:=auth.authenticateResponse(@buffer,@httpMethod,@httpPath)

    ' Authorization check
    ' You can comment this out if you want to
    ' be able to let unauthorized people see the
    ' front page.
    {
    if authorized<>auth#STAT_AUTH
      httpUnauthorized(authorized)
      socket.close
      next
    }
               
    queryPtr:=http.splitPathAndQuery(@httpPath)         
    if strcomp(@httpMethod,string("GET"))
      hits++
      if strcomp(@httpPath,string("/"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONTENT_TYPE_HTML)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        indexPage
      elseif strcomp(@httpPath,string("/reboot"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          socket.close
          next
        if strcomp(queryPtr,string("bootloader")) AND settings.findKey(settings#MISC_AUTOBOOT)
          settings.revert
          settings.removeKey(settings#MISC_AUTOBOOT)
          settings.commit
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.txmimeheader(string("Refresh"),string("12;url=/"))        
        socket.str(@CR_LF)
        socket.str(string("REBOOTING",13,10))
        delay_ms(1000)
        socket.close
        delay_ms(1000)
        reboot
      elseif strcomp(@httpPath,string("/chirp"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        subsys.chirpHappy
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/groan"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        subsys.chirpSad
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/click"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        subsys.click
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/sony"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        tmp1~
        tmp2~
        tmp3:=3
        if http.getFieldFromQuery(queryPtr,string("addr"),@buffer,127)
          tmp2:=atoi(@buffer)
        if http.getFieldFromQuery(queryPtr,string("cmd"),@buffer,127)
          tmp1:=atoi(@buffer)
        if http.getFieldFromQuery(queryPtr,string("r"),@buffer,127)
          tmp3:=atoi(@buffer)&255
        repeat tmp3
          sony_out.sendCode(tmp1,tmp2)
        socket.str(string("OK",13,10))
         
      elseif strcomp(@httpPath,string("/change"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        tmp1:=3
        if http.getFieldFromQuery(queryPtr,string("chan"),@buffer,127)
          tmp1:=atoi(@buffer)

        if tmp1 < 99        
          repeat 4
            sony_out.sendCode(sony_out#CMD_PWR_ON,sony_out#ADDR_TV)
          pause.delay_ms(40)
          if(tmp1=>10)
            tmp2:=(tmp1/10)
            socket.tx(tmp2+"0")
            repeat 4
              sony_out.sendCode(tmp2-1,sony_out#ADDR_TV)
          pause.delay_ms(40)
          tmp1//=10
          socket.tx(tmp1+"0")
          if(tmp1 == 0)
            tmp1 := 10
          repeat 4
            sony_out.sendCode(tmp1 - 1,sony_out#ADDR_TV)
          pause.delay_ms(40)
          repeat 4
            sony_out.sendCode(sony_out#CMD_ENTER,sony_out#ADDR_TV)
            
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/toggle"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        dira[30]:=1
        outa[30]:=!outa[30]
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/led"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        byte[queryPtr][6]:=0
        i:=numbers.FromStr(queryPtr,numbers#HEX)
        subsys.fadeToColor(byte[@i][2],byte[@i][1],byte[@i][0],1000)
        socket.hex(byte[@i][2],2)
        socket.hex(byte[@i][1],2)
        socket.hex(byte[@i][0],2)
        socket.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/print"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        http.unescapeURLInPlace(queryPtr)
        term.str(@httpQuery)
        term.out(13)
        socket.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/led_rainbow"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        subsys.statusIdle
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/irtest"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        subsys.irTest
        socket.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/poweroff"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.txmimeheader(string("Refresh"),string("0;url=/"))        
        socket.str(@CR_LF)

        repeat 4
          sony_out.sendCode(sony_out#CMD_PWR_OFF,sony_out#ADDR_TV)
        X10.send(settings.getByte(settings#MISC_X10_HOUSE),1)
      elseif strcomp(@httpPath,string("/poweron"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.txmimeheader(string("Refresh"),string("0;url=/"))        
        socket.str(@CR_LF)

        repeat 4
          sony_out.sendCode(sony_out#CMD_PWR_ON,sony_out#ADDR_TV)
        X10.send(settings.getByte(settings#MISC_X10_HOUSE),3)
      
      elseif strcomp(@httpPath,string("/sendx10"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.txmimeheader(string("Refresh"),string("0;url=/"))        
        socket.str(@CR_LF)
        house := settings.getByte(settings#MISC_X10_HOUSE)
        code := -1
        unit := -1
        tmp1 := -1
        tmp2 := -1
        
        if http.getFieldFromQuery(queryPtr,string("house"),@buffer,10)
          house:=atoi(@buffer)
        socket.str(string(" house="))
        socket.dec(house)
        if http.getFieldFromQuery(queryPtr,string("unit"),@buffer,10)
          unit:=atoi(@buffer)
          socket.str(string(" unit="))
          socket.dec(unit)
        if http.getFieldFromQuery(queryPtr,string("code"),@buffer,10)
          code:=atoi(@buffer)
          socket.str(string(" code="))
          socket.dec(code)
          if (unit <> -1)
            X10.send_to_unit(house,unit,code)
          else
            X10.send(house,code)
          socket.str(string(" SENT"))
        elseif http.getFieldFromQuery(queryPtr,string("extcmd"),@buffer,10)
          code:=atoi(@buffer)
          if http.getFieldFromQuery(queryPtr,string("data"),@buffer,10)
            tmp1:=atoi(@buffer)
          socket.str(string(" extcmd="))
          socket.dec(code)
          socket.str(string(" data="))
          socket.dec(tmp1)
          X10.send_ext_to_unit(house,unit,code,tmp1)
          socket.str(string(" SENT"))

        if http.getFieldFromQuery(queryPtr,string("dim"),@buffer,10)
          tmp2:=atoi(@buffer)
          socket.str(string(" dim="))
          socket.dec(tmp2)
          X10.dim(house,tmp2)
          socket.str(string(" SENT"))
        if http.getFieldFromQuery(queryPtr,string("bright"),@buffer,10)
          tmp2:=atoi(@buffer)
          socket.str(string(" bright="))
          socket.dec(tmp2)
          X10.bright(house,tmp2)
          socket.str(string(" SENT"))
          
        socket.str(@CR_LF)
      else           
        term.str(string("404",13))
        socket.str(@HTTP_404)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.str(@HTTP_404)
    else
      term.str(string("501",13))
      socket.str(@HTTP_501)
      socket.str(@HTTP_CONNECTION_CLOSE)
      socket.str(@CR_LF)
      socket.str(@HTTP_501)
       
    socket.close


pri httpOutputLink(url,class,content)
  socket.str(string("<a href='"))
  socket.strxml(url)
  if class
    socket.str(string("' class='"))
    socket.strxml(class)
  socket.str(string("'>"))
  socket.str(content)
  socket.str(string("</a>"))

pri indexPage | i
  'term.str(string("Sending index page",13))

  socket.str(string("<html><head manifest='http://www.deepdarc.com/ybox2.manifest'><meta name='viewport' content='width=320' /><meta name='apple-mobile-web-app-capable' content='yes'><title>ybox2</title>"))
  socket.str(string("<link rel='stylesheet' href='http://www.deepdarc.com/ybox2.css' />"))
  socket.str(string("</head><body><h1>"))
  socket.str(@productName)
  socket.str(string("</h1>"))
  if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
    socket.str(string("<div><tt>MAC: "))
    repeat i from 0 to 5
      if i
        socket.tx(":")
      socket.hex(byte[@httpMethod][i],2)
    socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>Uptime: "))
  socket.dec(subsys.RTC/3600)
  socket.tx("h")
  socket.dec(subsys.RTC/60//60)
  socket.tx("m")
  socket.dec(subsys.RTC//60)
  socket.tx("s")
  socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>Hits: "))
  socket.dec(hits)
  socket.str(string("</tt></div>"))
  {
  socket.str(string("<div><tt>INA: "))
  repeat i from 0 to 7
    socket.dec(ina[i])
  socket.tx(" ")
  repeat i from 8 to 15
    socket.dec(ina[i])
  socket.tx(" ")
  repeat i from 16 to 23
    socket.dec(ina[i])
  socket.tx(" ")
  repeat i from 23 to 31
    socket.dec(ina[i])          
  socket.str(string("</tt></div>"))
  }
   
  socket.str(string("<h2>Actions</h2>"))

  socket.str(string("<h3>Lights</h3><p>"))
  httpOutputLink(string("sendx10?code=3"),string("green button"),string("All Lights On"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sendx10?code=13"),string("red button"),string("All Lights Off"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sendx10?unit=28&code=5"),string("green button"),string("Track Lights On"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sendx10?unit=28&code=7"),string("red button"),string("Track Lights Off"))
  socket.str(string("</p><p>"))
  ' 14 levels
  httpOutputLink(string("sendx10?unit=28&bright=1"),string("green button"),string("Track Lights Brighter"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sendx10?unit=28&dim=1"),string("red button"),string("Track Lights Dimmer"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sendx10?unit=28&code=5&dim=14&bright=5"),string("yellow button"),string("Track Lights Mood"))

  socket.str(string("</p><h3>TV</h3><p>"))
  httpOutputLink(string("sony?cmd=46&addr=1"),string("green button"),string("TV On"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sony?cmd=47&addr=1"),string("red button"),string("TV Off"))
  socket.str(string("</p><h3>TV Input</h3><p>"))
  httpOutputLink(string("sony?cmd=64&addr=1"),string("white button"),string("ybox2"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sony?cmd=65&addr=1"),string("white button"),string("Video 2"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sony?cmd=54&addr=164"),string("white button"),string("Cable Box"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("sony?cmd=55&addr=164"),string("white button"),string("Mac mini"))
  socket.str(string("</p>"))

  socket.str(string("<h3>LED</h3>"))
  socket.str(string("<p>"))
  httpOutputLink(string("/led?ff0000"),string("red button"),string("Red"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/led?ffff00"),string("yellow button"),string("Yellow"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/led?00ff00"),string("green button"),string("Green"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/led?0000ff"),string("blue button"),string("Blue"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/led_rainbow"),string("white button"),string("Rainbow"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/irtest"),string("white button"),string("IR Test"))

  socket.str(string("</p><h3>All</h3><p>"))
  httpOutputLink(string("/poweron"),string("green button"),string("All On"))
  socket.str(string("</p><p>"))
  httpOutputLink(string("/poweroff"),string("red button"),string("All Off"))


  socket.str(string("<h3>System</h3>"))
  socket.str(string("<p>"))
  httpOutputLink(string("/reboot"),string("black button"),string("Reboot"))
  socket.str(string("</p>"))
  
  socket.str(string("<h2>Other</h2>"))
  httpOutputLink(@productURL,0,@productURL)
   
  socket.str(string("</body></html>",13,10))

  'term.str(string("Index page sent!",13))
  