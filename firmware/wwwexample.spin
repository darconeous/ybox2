{{
        ybox2 - Webserver Example
        http://www.deepdarc.com/ybox2
}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
OBJ

  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  numbers       : "numbers"
  socket       : "api_telnet_serial"
  http         : "http"
                                     
VAR
  long stack[100] 
  byte stage_two
DAT
productName   BYTE      "ybox2 webserver example",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0

PUB init | i
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
  settings.start
  numbers.init

  ' If you aren't using this thru the bootloader, set your
  ' settings here. 
  'settings.setData(settings#NET_MAC_ADDR,string(02,01,01,01,01,01),6)  
  'settings.setLong(settings#MISC_LED_CONF,$000A0B09)
  
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

  if settings.getData(settings#NET_MAC_ADDR,@stack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@stack][i],2)
    term.out(13)  

  if settings.findKey(settings#MISC_SOUND_DISABLE) == FALSE
    dira[subsys#SPKRPin]:=1
  else
    dira[subsys#SPKRPin]:=0
  
  dira[0]:=0

  if not \socket.start(1,2,3,4,6,7,-1,-1)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    subsys.chirpSad
    waitcnt(clkfreq*10000 + cnt)
    reboot

  subsys.chirpHappy

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

  subsys.StatusIdle
 
  httpServer

PUB showMessage(str)
  term.str(string($1,$B,12,$C,$1))    
  term.str(str)    
  term.str(string($C,$8))    

PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
VAR
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[64]
  byte httpHeader[32]
  byte buffer[128]

DAT
HTTP_200      BYTE      "HTTP/1.1 200 OK"
CR_LF         BYTE      13,10,0
HTTP_303      BYTE      "HTTP/1.1 303 See Other",13,10,0
HTTP_404      BYTE      "HTTP/1.1 404 Not Found",13,10,0
HTTP_411      BYTE      "HTTP/1.1 411 Length Required",13,10,0
HTTP_501      BYTE      "HTTP/1.1 501 Not Implemented",13,10,0

HTTP_CONTENT_TYPE_HTML  BYTE "Content-Type: text/html; charset=utf-8",13,10,0
HTTP_CONNECTION_CLOSE   BYTE "Connection: close",13,10,0

pub httpServer | char, i, lineLength,contentLength

  repeat
    repeat while \socket.listen(80) == -1
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(1000)
      socket.closeall
      next
    socket.resetBuffers
    repeat while NOT socket.isConnected
      socket.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot

    http.parseRequest(socket.handle,@httpMethod,@httpPath,@httpQuery)
  
    contentLength:=0
    repeat while http.getNextHeader(socket.handle,@httpHeader,32,@buffer,128)
      if strcomp(@httpHeader,string("Content-Length"))
        contentLength:=numbers.fromStr(@buffer,numbers#DEC)
               
    if strcomp(@httpMethod,string("GET"))
      if strcomp(@httpPath,string("/"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONTENT_TYPE_HTML)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        indexPage
      elseif strcomp(@httpPath,string("/reboot"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
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
        httpQuery[6]:=0
        i:=numbers.FromStr(@httpQuery,numbers#HEX)
        subsys.statusSolid(byte[@i][2],byte[@i][1],byte[@i][0])
        socket.hex(byte[@i][2],2)
        socket.hex(byte[@i][1],2)
        socket.hex(byte[@i][0],2)
        socket.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/print"))
        socket.str(@HTTP_303)
        socket.str(string("Location: /",13,10))
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        http.unescapeURLInPlace(@httpQuery)
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
      else           
        socket.str(@HTTP_404)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.str(@HTTP_404)
    else
        socket.str(@HTTP_501)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.str(@HTTP_501)
    
    socket.close



pri indexPage | i
  socket.str(string("<html><head><title>ybox2</title></head><body><h1>"))
  socket.str(@productName)
  socket.str(string("</h1><hr />"))
  socket.str(string("<h2>Info</h2>"))
  if settings.getData(settings#NET_MAC_ADDR,@httpMethod,6)
    socket.str(string("<div><tt>MAC: "))
    repeat i from 0 to 5
      if i
        socket.tx("-")
      socket.hex(byte[@httpMethod][i],2)
    socket.str(string("</tt></div>"))
  if settings.getData(settings#MISC_UUID,@httpQuery,16)
    socket.str(string("<div><tt>UUID: "))
    repeat i from 0 to 3
      socket.hex(byte[@httpQuery][i],2)
    socket.tx("-")
    repeat i from 4 to 5
      socket.hex(byte[@httpQuery][i],2)
    socket.tx("-")
    repeat i from 6 to 7
      socket.hex(byte[@httpQuery][i],2)
    socket.tx("-")
    repeat i from 8 to 9
      socket.hex(byte[@httpQuery][i],2)
    socket.tx("-")
    repeat i from 10 to 15
      socket.hex(byte[@httpQuery][i],2)
    socket.str(string("</tt></div>"))
  socket.str(string("<div><tt>RTC: "))
  socket.dec(subsys.RTC)
  socket.str(string("</tt></div>"))
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
   
  socket.str(string("<h2>Actions</h2>"))
  socket.str(string("<div>Noise: <a href='/chirp'>Chirp</a> | <a href='/groan'>Groan</a></div>"))
  socket.str(string("<div>LED: <a href='/led?ff0000'>Red</a> | <a href='/led?00ff00'>Green</a> | <a href='/led?ffff00'>Yellow</a> | <a href='/led?0000ff'>Blue</a> | <a href='/led_rainbow'>Rainbow</a> | <a href='/irtest'>irtest</a></div>"))
  socket.str(string("<div>Other: <a href='/reboot'>Reboot</a></div>"))
  socket.str(string("<h2>Other</h2>"))
  socket.str(string("<div><a href='"))
  socket.str(@productURL)
  socket.str(string("'>More info</a></div>"))
   
  socket.str(string("</body></html>",13,10))
  