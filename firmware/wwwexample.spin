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

'  tel           : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
'  eeprom        : "Basic_I2C_Driver"
'  random        : "RealRandom"
  numbers       : "numbers"
                                     
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
    'term.out($86)
  term.out($0c)
  term.out(0)
  'term.out(13)
  
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

  if not \http.start(1,2,3,4,6,7,-1,-1)
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

  subsys.StatusIdle
 
  httpServer

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
VAR
  byte httpMethod[8]
  byte httpPath[64]
  byte httpQuery[64]
  byte httpHeader[32]

DAT
HTTP_200      BYTE      "HTTP/1.1 200 OK"
CR_LF         BYTE      13,10,0
HTTP_303      BYTE      "HTTP/1.1 303 See Other",13,10,0
HTTP_404      BYTE      "HTTP/1.1 404 Not Found",13,10,0
HTTP_411      BYTE      "HTTP/1.1 411 Length Required",13,10,0
HTTP_501      BYTE      "HTTP/1.1 501 Not Implemented",13,10,0

HTTP_CONTENT_TYPE_HTML  BYTE "Content-Type: text/html; charset=utf-8",13,10,0
HTTP_CONNECTION_CLOSE   BYTE "Connection: close",13,10,0

pub httpServer | char, i, lineLength,contentSize

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
    repeat while NOT http.isConnected
      http.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        reboot
    i:=0

    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<7
      httpMethod[i]:=char
      if httpMethod[i] == " "
        quit
      i++
    httpMethod[i]:=0
    i:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<63
      httpPath[i]:=char
      if httpPath[i] == " " OR httpPath[i] == "?"  OR httpPath[i] == "#"
        quit
      i++

    httpQuery[0]:=0
    if httpPath[i]=="?"
      ' If we stopped on a question mark, then grab the query
      httpPath[i]:=0
      i:=0
      repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<63
        httpQuery[i]:=char
        if httpQuery[i] == " " OR httpPath[i] == "#"
          quit
        i++        
    else
      httpPath[i]:=0
    httpQuery[i]:=0
  
    lineLength:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF)
      if (char == 13)
        ifnot lineLength
          quit
        lineLength:=0
      else
        if (char <> 10)
          if lineLength<31
            httpHeader[lineLength]:=char
            if char == ":"
              httpHeader[lineLength]:=0
              if strcomp(@httpHeader,string("Content-Length"))
                contentSize := http.readDec
                lineLength:=1
          lineLength++
             
    if strcomp(@httpMethod,string("GET"))
      if strcomp(@httpPath,string("/"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<html><head><title>ybox2</title></head><body><h1>"))
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
        
        http.str(string("<h2>Actions</h2>"))
        http.str(string("<div>Noise: <a href='/chirp'>Chirp</a> | <a href='/groan'>Groan</a></div>"))
        http.str(string("<div>LED: <a href='/led?ff0000'>Red</a> | <a href='/led?00ff00'>Green</a> | <a href='/led?ffff00'>Yellow</a> | <a href='/led?0000ff'>Blue</a> | <a href='/led_rainbow'>Rainbow</a></div>"))
        http.str(string("<div>Other: <a href='/reboot'>Reboot</a></div>"))
        http.str(string("<h2>Other</h2>"))
        http.str(string("<div><a href='"))
        http.str(@productURL)
        http.str(string("'>More info</a></div>"))

        http.str(string("</body></html>",13,10))
        
      elseif strcomp(@httpPath,string("/reboot"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<h1>Rebooting</h1>",13,10))
        delay_ms(1000)
        http.close
        delay_ms(1000)
        reboot
      elseif strcomp(@httpPath,string("/chirp"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        HappyChirp
        http.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/groan"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        SadChirp
        http.str(string("OK",13,10))
      elseif strcomp(@httpPath,string("/led"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        httpQuery[6]:=0
        i:=numbers.FromStr(@httpQuery,numbers#HEX)
        subsys.statusSolid(byte[@i][2],byte[@i][1],byte[@i][0])
        http.hex(byte[@i][2],2)
        http.hex(byte[@i][1],2)
        http.hex(byte[@i][0],2)
        http.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/print"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        term.str(@httpQuery)
        term.out(13)
        http.str(string(" OK",13,10))
      elseif strcomp(@httpPath,string("/led_rainbow"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        subsys.statusIdle
        http.str(string("OK",13,10))
      else           
        http.str(@HTTP_404)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(@HTTP_404)
    else
        http.str(@HTTP_501)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(@HTTP_501)
    
    http.close



  