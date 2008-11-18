{{
        ybox2 - One-Wire Bridge
        http://www.deepdarc.com/ybox2

        ABOUT

        This is a simple HTTP interface to
        a one-wire bus.
}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  MAX_DEVICES       = 10                                ' maximum number of 1-wire devices
  OW_PIN = 30
OBJ

  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  numbers       : "numbers"
  socket        : "api_telnet_serial"
  http          : "http"
  base16        : "base16"
  auth          : "auth_digest"
  ow            : "OneWire"
  fp            : "FloatString"
  f             : "FloatMath"                           ' could also use Float32
                                   
VAR
  long stack[100] 
  byte stage_two
  byte tv_mode
  long hits

  long  addressList[MAX_DEVICES*2]                      ' 64-bit address buffer
  
DAT
productName   BYTE      "ybox2 One Wire Bridge",0      
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

  ow.start(30)
  outa[31]~
  dira[31]~~
  outa[OW_PIN]~~
 
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

pub httpServer | char, i, contentLength,authorized,queryPtr,tempC,tempF

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
    repeat while http.getNextHeader(socket.handle,@httpHeader,32,@buffer,128)
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
        socket.close
        delay_ms(100)
        reboot
      elseif strcomp(@httpPath,string("/alarm"))
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONTENT_TYPE_HTML)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        deviceTable(0,ow#CMD_SEARCH_ALARM)
      elseif strcomp(@httpPath,string("/temp"))
        if byte[queryPtr]
          base16.inplaceDecode(queryPtr)
          selectDevice(queryPtr)
          convertTemperature
          selectDevice(queryPtr)
          tempC := getTemperature                             ' get temperature in celsius
        else
          selectAnyDevice    
          convertTemperature
          selectAnyDevice    
          tempC := getTemperature                             ' get temperature in celsius
        
        socket.str(@HTTP_200)
        socket.str(@HTTP_CONNECTION_CLOSE)
        socket.str(@CR_LF)
        socket.dec(subsys.rtc)
        socket.str(string(", "))
        socket.str(fp.FloatToString(tempC))
        socket.str(string(", "))
        socket.hex(ow.readByte,2)
        socket.str(string(", "))
        socket.hex(ow.readByte,2)
        socket.str(string(", "))
        socket.hex(ow.readByte,2)
        socket.str(@CR_LF)
        
         
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


pri httpOutputLink(url,class,content)
  socket.str(string("<a href='"))
  socket.strxml(url)
  if class
    socket.str(string("' class='"))
    socket.strxml(class)
  socket.str(string("'>"))
  socket.str(content)
  socket.str(string("</a>"))
pri httpOutputROMCode(p)
  repeat 8
    socket.hex(byte[p++],2)
   
pri indexPage | i, tempF, tempC, p
  'term.str(string("Sending index page",13))

  socket.str(string("<html><head><meta name='viewport' content='width=320' /><title>ybox2</title>"))
  'socket.str(string("<link rel='stylesheet' href='http://www.deepdarc.com/ybox2.css' />"))
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
{
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
}

  deviceTable(0,ow#CMD_SEARCH_ROM)

{
  i := ow.search(0, MAX_DEVICES, @addressList,ow#CMD_SEARCH_ROM)          ' search the 1-wire network
  socket.str(string("<div><tt>Devices Found: "))
  socket.dec(i)
  socket.str(string("</tt></div>"))
  
  p := @addressList
  socket.str(string("<table><thead><tr><th>Type</th><th>ROM Code</th></tr></thead><tbody>"))
  repeat i 
    socket.str(string("<tr><th>"))
    case byte[p]                                        ' display family name
      $01:    socket.str(@ds2401_name)
      $05:    socket.str(@ds2405_name)
      $10,$28,$22:
        socket.str(string("<a href='/temp?"))
        httpOutputROMCode(p)
        socket.str(string("'>DS1820</a>"))
      other:  socket.str(string("Unknown "))
    socket.str(string("</th><th><tt>"))
    httpOutputROMCode(p)
    if ow.crc8(8, p) <> 0                               ' check crc of address
      socket.str(string("?crc"))
    p += 8
    socket.str(string("</tt></th><tr>"))
  socket.str(string("</tbody></table>"))
}
   
  {
  socket.str(string("<h2>Actions</h2>"))
  socket.str(string("<h3>System</h3>"))
  socket.str(string("<p>"))
  }
  httpOutputLink(string("/reboot"),string("black button"),string("Reboot"))
  'socket.str(string("</p>"))
  
  socket.str(string("<h2>Other</h2>"))
  httpOutputLink(@productURL,0,@productURL)
   
  socket.str(string("</body></html>",13,10))

  'term.str(string("Index page sent!",13))

PUB deviceTable(family, command)| i,p
  i := ow.search(family, MAX_DEVICES, @addressList,command)          ' search the 1-wire network
  socket.str(string("<div><tt>Devices Found: "))
  socket.dec(i)
  socket.str(string("</tt></div>"))
  
  p := @addressList
  socket.str(string("<table><thead><tr><th>Type</th><th>ROM Code</th></tr></thead><tbody>"))
  repeat i 
    socket.str(string("<tr><th>"))
    case byte[p]                                        ' display family name
      $01:    socket.str(@ds2401_name)
      $05:    socket.str(@ds2405_name)
      $10,$28,$22:
        socket.str(string("<a href='/temp?"))
        httpOutputROMCode(p)
        socket.str(string("'>DS1820</a>"))
      other:  socket.str(string("Unknown "))
    socket.str(string("</th><th><tt>"))
    httpOutputROMCode(p)
    if ow.crc8(8, p) <> 0                               ' check crc of address
      socket.str(string("?crc"))
    p += 8
    socket.str(string("</tt></th><tr>"))
  socket.str(string("</tbody></table>"))


DAT
ds2401_name     byte    "DS2401 ", 0
ds2405_name     byte    "DS2405 ", 0 
ds1820_name     byte    "DS1820 ", 0 
ds18B20_name     byte   "DS18B20 ", 0 
ds1822_name     byte    "DS1822 ", 0 

CON
  MATCH_ROM          = $55                               ' 1-wire commands
  SKIP_ROM          = $CC                               ' 1-wire commands
  READ_SCRATCHPAD   = $BE
  WRITE_SCRATCHPAD   = $4E
  COPY_SCRATCHPAD   = $48
  REVERT_SCRATCHPAD   = $B8
  CONVERT_T         = $44
  POWER_SUPPLY    = $B4
  
PUB selectDevice(p)
  ow.reset                                              ' send convert temperature command
  ow.writeByte(MATCH_ROM)
  ow.writeAddress(p)

PUB selectAnyDevice
  ow.reset                                              ' send convert temperature command
  ow.writeByte(SKIP_ROM)

PUB convertTemperature
  ow.writeByte(CONVERT_T)
  dira[OW_PIN]~~
  delay_ms(750)
  dira[OW_PIN]~
  
  repeat                                                ' wait for conversion
    waitcnt(cnt+clkfreq/1000*25)
    if ow.readBits(1)
      quit
PUB getScratchpad(ptr,len)
  ow.writeByte(READ_SCRATCHPAD)
  repeat len
    BYTE[ptr++]:=ow.readByte

PUB setAlarmTemps(hi,lo)
  ow.writeByte(WRITE_SCRATCHPAD)
  ow.writeByte(hi.byte[1])
  ow.writeByte(lo.byte[1])
  ow.writeByte(%0_11_11111)

PUB commitAlarmTemps
  ow.writeByte(COPY_SCRATCHPAD)
  dira[OW_PIN]~~
  delay_ms(10)
  dira[OW_PIN]~

PUB revertAlarmTemps
  ow.writeByte(REVERT_SCRATCHPAD)
  
  
PUB TempToFloat(temp)
  return F.FDiv(F.FFloat(temp), 16.0)

PUB isParasitePowered
  ow.writeByte(POWER_SUPPLY)
  return NOT ina[OW_PIN]
  
PUB getTemperature : temp
  getScratchpad(@temp,2)
  'ow.writeByte(READ_SCRATCHPAD)
  'temp := ow.readByte + ow.readByte << 8                ' read temperature
  temp := ( temp << 16 ) ~> 16
  temp := TempToFloat(temp)
'  temp := F.FDiv(F.FFloat(temp), 16.0)                  ' convert to floating point
  