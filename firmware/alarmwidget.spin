{{
        ybox2 - Alarm Clock widget
        http://www.ladyada.net/make/ybox2

        ABOUT

        This simple (!?) program will get the current UTC time from a navy time server
        and display it. You can set the time zone, alarm time and alarm mode using the webbrowser

        If a password was set in the bootloader, it will be
        required to change the settings.
}}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      


  clk_y_off = 2
  clk_x_off = 0
  pixelchar = 14  
OBJ

  websocket     : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  http          : "http"
  auth          : "auth_digest"
  tel           : "api_telnet_serial"
  random        : "RealRandom"
  num           : "Numbers"
                                       
VAR
  byte path_holder[128]
  byte tv_mode

  ' Statistics
  long stat_refreshes
  long stat_errors

  long clockstack[200]
  long myip[4]
  
  byte month, date, minute, hour, sec, alarming

DAT
productName   BYTE      "digital clock widget",0      
productURL    BYTE      "http://www.ladyada.net/make/ybox2/",0

info_refresh_period   long    60*60*12  ' in seconds
    
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
  term.setcolors(@palette)  
  term.str(string($0C,1))
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

  ' Init the auth object with some randomness
  random.start
  auth.init(random.random)
  random.stop

  if settings.findKey(settings#MISC_STAGE2)
    settings.removeKey(settings#MISC_STAGE2)

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
  if not \tel.start(1,2,3,4,6,7)
    showMessage(string("Unable to start networking!"))
    subsys.StatusFatalError
    SadChirp
    waitcnt(clkfreq*10000 + cnt)
    reboot

  if settings.getData(settings#NET_MAC_ADDR,@clockstack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@clockstack][i],2)
    term.out(13)  

  if NOT settings.getData(settings#NET_IPv4_ADDR,@clockstack,4)
    term.str(string("IPv4 ADDR: DHCP..."))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@clockstack,4)
      if ina[subsys#BTTNPin]
        reboot
      delay_ms(500)
  term.out($0A)
  term.out($00)  
  term.str(string("IPv4 ADDR: "))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@clockstack][i])
  term.out(13)  


  if settings.getData(settings#NET_IPv4_DNS,@clockstack,4)
    term.str(string("DNS ADDR: "))
    repeat i from 0 to 3
      if i
        term.out(".")
      term.dec(byte[@clockstack][i])
    term.out(13)  

  \initial_configuration
  
  if settings.getData(settings#SERVER_IPv4_ADDR,@clockstack,4)
    term.str(string("SERVER ADDR:"))
    repeat i from 0 to 3
      if i
        term.out(".")
      term.dec(byte[@clockstack][i])
    term.out(":")  
    term.dec(settings.getWord(settings#SERVER_IPv4_PORT))
    term.out(13)  

  if settings.getString(settings#SERVER_PATH,@clockstack,40)
    term.str(string("SERVER PATH:'"))
    term.str(@clockstack)
    term.str(string("'",13))

  if settings.getString(settings#SERVER_HOST,@clockstack,40)
    term.str(string("SERVER HOST:'"))
    term.str(@clockstack)
    term.str(string("'",13))
   
  cognew(ClockCog, @clockstack) 
  
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

  settings.setString(settings#SERVER_HOST,string("tycho.usno.navy.mil"))  
  settings.setData(settings#SERVER_IPv4_ADDR,string(199,211,133,239),4)
  settings.setWord(settings#SERVER_IPv4_PORT,80)
  settings.setString(settings#SERVER_PATH,string("/cgi-bin/timer.pl"))
  return TRUE
 
PUB drawbigchar(charx, chary, bitmap)  | i, j
    term.out($A)
    term.out(charx)
    term.out($B)
    term.out(chary)
    repeat i from 0 to 6
      'term.hex(BYTE[bitmap][i],2)
      repeat j from 4 to 0
         if(BYTE[bitmap][i] & (1 << j))
            term.out(pixelchar)
         else
            term.out(32)
      term.out($A)
      term.out(charx)
      term.out($B)
      term.out(chary+i+1)

CON
  CLOCK_SUCCESS = 860276
pub Alarm | i
  dira[subsys#SPKRPin]:=1
  repeat i from 0 to 30
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    delay_ms(1)
  outa[subsys#SPKRPin]:=0  
  delay_ms(50)
   
pub fillscreen | i
  term.out(1)
  repeat i from 0 to 600
     term.str(string(" "))
     
pub ClockCog | retrydelay,port,err, currtime, i 
  port := 20000
  retrydelay := 1 ' Reset the retry delay

  repeat
    if (err:=\ClockUpdate(port)) == CLOCK_SUCCESS
      retrydelay := 1 ' Reset the retry delay
      subsys.StatusIdle
      
      ' print out the clock
      term.str(string($C,7))
      term.out(0)
      term.out(1)

      repeat
        'subsys.Click
        if ((settings.getByte(settings#TIMEZONE) < 0) or (settings.getByte(settings#TIMEZONE) > 49))
          settings.setByte(settings#TIMEZONE, 24)                 
        currtime := subsys.RTC + ((settings.getByte(settings#TIMEZONE) + 24) * 1800)

        sec := currtime // 60
        minute := (currtime/60) // 60
        hour := (currtime / 3600) // 24

        if alarming
          if (sec & 1)
            term.setcolors(@paletteALARM)  
          else
            term.setcolors(@palette)  
          
        drawbigchar(0, clk_y_off, @num0+(hour/10)*7)
        drawbigchar(6, clk_y_off, @num0+(hour//10)*7)
        
        drawbigchar(14, clk_y_off, @num0+(minute/10)*7)
        drawbigchar(20, clk_y_off, @num0+(minute//10)*7)

        drawbigchar(28, clk_y_off, @num0+(sec/10)*7)
        drawbigchar(34, clk_y_off, @num0+(sec//10)*7)

        if (settings.getByte(settings#ALARM_ON))
           term.str(string($A, 26, $B, 12, "Alarm @ "))
           i := settings.getByte(settings#ALARM_HOUR) 
           term.dec(i/10)
           term.dec(i//10)          
           term.str(string(":"))
           i := settings.getByte(settings#ALARM_MIN)
           term.dec(i/10)
           term.dec(i//10)

           ' now check if we're ready to alarm!
           if ((settings.getByte(settings#ALARM_HOUR) == hour) and (settings.getByte(settings#ALARM_MIN) == minute))
              alarming := 1
           else
{
              if (alarming)  
                term.str(string($C, 7))
                term.out(0)
}
              alarming := 0
                
        else
           term.str(string($A, 26, $B, 12, "             "))

        
        'term.str(string("Time zone: "))
        'term.dec(settings.getByte(settings#TIMEZONE))

        settings.getData(settings#NET_IPv4_ADDR,@myip,4)
        term.str(string($A, 1, $B, 12, "IP: "))
        repeat i from 0 to 3
          if i
            term.out(".")
          term.dec(byte[@myip][i])

        
        repeat
          if alarming
            Alarm
        while currtime == subsys.RTC + ((settings.getByte(settings#TIMEZONE) + 24) * 1800)
      term.str(string($B,12))
      term.dec(subsys.RTC) ' Print out the RTC value
      term.out(" ")
      
      tel.close
      delay_s(info_refresh_period)     ' 30 sec delay
    else
      if err>0
        subsys.StatusErrorCode(err)
      stat_errors++
      showMessage(string("Error!"))    
      tel.closeall
      websocket.closeall
      if retrydelay < 60
         retrydelay+=retrydelay
      delay_s(retrydelay)             ' failed to connect     
    if ++port > 30000
      port := 20000
       

pub ClockUpdate(port) | timeout, addr, gotstart,in,i,header[4],value[4], buffer_idx, stringptr
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
   
    repeat while \http.getNextHeader(tel.handle,@header,16,@value,16)>0
      if strcomp(string("Refresh"),@header)
        info_refresh_period:=atoi(@value)
        if info_refresh_period < 4
          info_refresh_period:=4 ' Four second minimum refresh  
        
    timeout := cnt
    i:=0
    repeat
      if (in := tel.rxcheck) > 0
       
          if in == 10  ' new line
            buffer[buffer_idx] := 0
            'term.str(@buffer)
            'term.dec(buffer_idx)
            if (strstrn(@buffer, string("<BR>"), BUFFMAX) <> -1) AND (strstrn(@buffer, string("UTC"), BUFFMAX) <> -1)
               ' we found <BR>
               'term.str(@buffer)
               stringptr := @buffer + 4
               term.str(stringptr)
               term.out(13)
               parseDateline(stringptr)
               i := 1 
               'my_cnt := cnt
               term.str(string("done!"))
               tel.close
               return CLOCK_SUCCESS
                 
            buffer_idx := 0                      ' prepare for next string buffer
          elseif buffer_idx < BUFFMAX            ' make sure we dont overrrun the string buffer
            buffer[buffer_idx] := in
            buffer_idx++
            
            
      else
        ifnot tel.isConnected
          if i
            return CLOCK_SUCCESS 
          abort 4
        if cnt-timeout>10*clkfreq ' 10 second timeout      
          abort(subsys#ERR_DISCONNECTED)
  else
    abort(subsys#ERR_NO_CONNECT)
  return 5

PUB parseDateline(str)  ' in form something like "Mon. dd, hh:mm:ss"
   'term.str(str)
   ' Find month first
   if (strstrn(str, string("Jan"), 3) == 0)
      month := 1
   elseif (strstrn(str, string("Feb"), 3) == 0)
      month := 2
   elseif (strstrn(str, string("Mar"), 3) == 0)
      month := 3
   elseif (strstrn(str, string("Apr"), 3) == 0)
      month := 4
   elseif (strstrn(str, string("May"), 3) == 0)
      month := 5
   elseif (strstrn(str, string("Jun"), 4) == 0)
      month := 6
   elseif (strstrn(str, string("Jul"), 3) == 0)
      month := 7      
   elseif (strstrn(str, string("Aug"), 3) == 0)
      month := 8
   elseif (strstrn(str, string("Sep"), 3) == 0)
      month := 9
   elseif (strstrn(str, string("Oct"), 3) == 0)
      month := 10
   elseif (strstrn(str, string("Nov"), 3) == 0)
      month := 11
   elseif (strstrn(str, string("Dec"), 3) == 0)
      month := 12

   'term.str(string("Month : "))
   'term.dec(month)
   'term.out(13)
   
   str += strstrn(str, string(". "), 10)+2
   'term.str(str)

   date := num.FromStr(str, NUM#DEC)

   'term.str(string("Date : "))
   'term.dec(date)
   'term.out(13)

   str += strstrn(str, string(", "), 10)+2
   'term.str(str)

   hour := num.FromStr(str, NUM#DEC)

   'term.str(string("Hour : "))
   'term.dec(hour)
   'term.out(13)

   str += strstrn(str, string(":"), 10)+1
   'term.str(str)
   
   minute := num.FromStr(str, NUM#DEC)

   'term.str(string("Min : "))
   'term.dec(minute)
   'term.out(13)

   str += strstrn(str, string(":"), 10)+1
   'term.str(str)
   
   sec := num.FromStr(str, NUM#DEC)

   'term.str(string("Sec : "))
   'term.dec(sec)
   'term.out(13)
   subsys.setRTC((hour * 3600) + (minute * 60) + sec)
   'RTCoffset:=0
   'RTCoffset := ((hour * 3600) + (minute * 60) + sec) - subsys.RTC
        
PUB strstrn(haystack, needle, len) | i, j   ' finds needle string in haystack string, up to len bytes long
   i := 0         ' string incrementer
   j := 0        ' substring incrementer
   RESULT := -1     ' our success (-1 not found, otherwise index of substr
   repeat i from 0 to len
      if BYTE[haystack][i] == 0      ' haystack over
         quit
      if (BYTE[haystack][i] == BYTE[needle][0])        ' start substr compare
         j := 0

         repeat while (j < strsize(needle))
           if ((i+j) => len)
              quit
           if BYTE[haystack][i+j] <> BYTE[needle][j]
              quit
           j++
         if j == strsize(needle)
            RESULT := i     ' success!
            return 

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
PRI delay_s(Duration)
  repeat Duration
    delay_ms(1000)  
VAR
  byte httpMethod[8]
  byte httpPath[128]
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

BUFFMAX BYTE 128

pri httpUnauthorized(authorized)
  websocket.str(@HTTP_401)
  websocket.str(@HTTP_CONNECTION_CLOSE)
  auth.generateChallenge(@buffer,127,authorized)
  websocket.txMimeHeader(string("WWW-Authenticate"),@buffer)
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

pub httpServer | i, j, contentLength,authorized,queryPtr,currentTime
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

    if \http.parseRequest(websocket.handle,@httpMethod,@httpPath)<0
      websocket.close
      next
        
    repeat while \http.getNextHeader(websocket.handle,@httpHeader,32,@buffer,128)>0
      if strcomp(@httpHeader,@HTTP_HEADER_CONTENT_LENGTH)
        contentLength:=atoi(@buffer)
      elseif NOT authorized AND strcomp(@httpHeader,string("Authorization"))
        authorized:=auth.authenticateResponse(@buffer,@httpMethod,@httpPath)

    ' Authorization check
    ' You can comment this out if you want to
    ' be able to let unauthorized people see the
    ' front page. Even if you uncomment this,
    ' unauthorized users won't be able to
    ' change the settings or reboot, due to
    ' redundant checks below.
    if authorized<>auth#STAT_AUTH
      httpUnauthorized(authorized)
      websocket.close
      next
             
    queryPtr:=http.splitPathAndQuery(@httpPath)
    if strcomp(@httpMethod,string("GET")) or strcomp(@httpMethod,string("POST"))
      if strcomp(@httpPath,string("/"))
        websocket.str(@HTTP_200)
        websocket.txmimeheader(@HTTP_HEADER_CONTENT_TYPE,@HTTP_CONTENT_TYPE_HTML)        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)

        websocket.str(string("<html><head><meta name='viewport' content='width=320' /><title>ybox2</title>"))
        'websocket.str(string("<link rel='stylesheet' href='http://www.deepdarc.com/ybox2.css' />"))
 
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

        websocket.str(string("<div><tt>Time: "))
        currentTime:=subsys.RTC+((settings.getByte(settings#TIMEZONE) + 24) * 1800 )
        websocket.dec(currentTime/3600//24)
        websocket.tx(":")
        websocket.dec((currentTime/60)//60)
        websocket.tx(":")
        websocket.dec(currentTime//60)
        websocket.str(string("</tt></div>"))

        websocket.str(string("<h2>Settings</h2>"))
        websocket.str(string("<form action='/config' method='POST'>"))
        websocket.str(string("Alarm:<br> <input type='radio' name='AO' value='1'"))
        if (settings.getByte(settings#ALARM_ON))
          websocket.str(string(" checked "))
        websocket.str(string("> On <input type='radio' name='AO' value='0' "))
        if (not settings.getByte(settings#ALARM_ON))
          websocket.str(string(" checked "))
        websocket.str(string("> Off<br>Time zone: <br> <select name='TZ' size='1'>"))

        j :=  settings.getByte(settings#TIMEZONE)
        repeat i from -11 to -1
          websocket.str(string("<option value="))
          websocket.dec(i*2+23)
          if (j == i*2+23)
            websocket.str(string(" SELECTED"))
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string(".5</option><option value="))
          websocket.dec(i*2+24)
          if (j == i*2+24)
            websocket.str(string(" SELECTED"))
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string("</option>"))
        websocket.str(string("<option value=23>-0.5</option>"))
        repeat i from 0 to 12
          websocket.str(string("<option value="))
          websocket.dec(i*2+24)
          if (j == i*2+24)
            websocket.str(string(" SELECTED"))
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string("</option><option value="))
          websocket.dec(i*2+25)
          if (j == i*2+25)
            websocket.str(string(" SELECTED"))    
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string(".5</option>"))
          
        websocket.str(string("</select> hours from UTC<br>"))

        websocket.str(string("Alarm time: <br> <select name='AH' size='1'>"))
        j :=  settings.getByte(settings#ALARM_HOUR)
        repeat i from 0 to 23
          websocket.str(string("<option value="))
          websocket.dec(i)
          if (j == i)
            websocket.str(string(" SELECTED "))
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string("</option>"))
        websocket.str(string("</select> : <select name='AM' size='1'>"))
        j :=  settings.getByte(settings#ALARM_MIN)  
        repeat i from 0 to 59
          websocket.str(string("<option value="))
          websocket.dec(i)
          if (j == i)
            websocket.str(string(" SELECTED "))
          websocket.str(string(">"))
          websocket.dec(i)
          websocket.str(string("</option>"))
        websocket.str(string("</select> <br>"))

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
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          websocket.close
          next

        if contentLength
          i:=0
          repeat while contentLength AND i<127
            httpPath[i++]:=websocket.rxtime(1000)
            contentLength--
          httpPath[i]~
          queryPtr:=@httpPath
         
        if http.getFieldFromQuery(queryPtr,string("AO"),@buffer,127)
          settings.setByte(settings#ALARM_ON,atoi(@buffer))
        
        if http.getFieldFromQuery(queryPtr,string("TZ"),@buffer,127)
          settings.setByte(settings#TIMEZONE, atoi(@buffer))  
          
        if http.getFieldFromQuery(queryPtr,string("AH"),@buffer,127)
          settings.setByte(settings#ALARM_HOUR, atoi(@buffer))  

        if http.getFieldFromQuery(queryPtr,string("AM"),@buffer,127)
          settings.setByte(settings#ALARM_MIN, atoi(@buffer))  
        
         
        settings.removeKey($1010)
        settings.removeKey(settings#MISC_STAGE2)
        settings.commit
        
        websocket.str(@HTTP_303)
        websocket.txmimeheader(@HTTP_HEADER_LOCATION,string("/"))        
        websocket.str(@HTTP_CONNECTION_CLOSE)
        websocket.str(@CR_LF)
        websocket.str(string("OK",13,10))

      elseif strcomp(@httpPath,string("/reboot"))
        if authorized<>auth#STAT_AUTH
          httpUnauthorized(authorized)
          websocket.close
          next
        if strcomp(queryPtr,string("bootloader")) AND settings.findKey(settings#MISC_AUTOBOOT)
          settings.revert
          settings.removeKey(settings#MISC_AUTOBOOT)
          settings.commit
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
DAT
paletteALARM            byte    $BB,   $CE    '6      black, white
palette                 byte    $07,   $B2    '0    white / dark blue
                        byte    $07,   $B2    '1    yellow / black
                        byte    $6B,   $B2    '2   yellow / brown
                        byte    $04,   $07    '3     grey / white
                        byte    $3D,   $3B    '4     cyan / dark cyan
                        byte    $6B,   $6E    '5    green / gray-green
                        byte    $BB,   $CE    '6      black, white
                        byte    $BC,   $B2    '7     red, black

                        
num0                    byte    %01110
                        byte    %10001
                        byte    %10011
                        byte    %10101
                        byte    %11001
                        byte    %10001
                        byte    %01110

num1                    byte    %00100
                        byte    %01100
                        byte    %00100
                        byte    %00100
                        byte    %00100
                        byte    %00100
                        byte    %01110
                        
num2                    byte    %01110
                        byte    %10001
                        byte    %00001
                        byte    %00010
                        byte    %00100
                        byte    %01000
                        byte    %11111

num3                    byte    %11111
                        byte    %00010
                        byte    %00100
                        byte    %00010
                        byte    %00001
                        byte    %10001
                        byte    %01110

num4                    byte    %00010
                        byte    %00110
                        byte    %01010
                        byte    %10010
                        byte    %11111
                        byte    %00010
                        byte    %00010

num5                    byte    %11111
                        byte    %10000
                        byte    %11110
                        byte    %00001
                        byte    %00001
                        byte    %10001
                        byte    %01110

num6                    byte    %00111
                        byte    %01000
                        byte    %10000
                        byte    %11110
                        byte    %10001
                        byte    %10001
                        byte    %01110

num7                    byte    %11111
                        byte    %00001
                        byte    %00010
                        byte    %00100
                        byte    %01000
                        byte    %01000
                        byte    %01000

num8                    byte    %01110
                        byte    %10001
                        byte    %10001
                        byte    %01110
                        byte    %10001
                        byte    %10001
                        byte    %01110                        

num9                    byte    %01110
                        byte    %10001
                        byte    %10001
                        byte    %01111
                        byte    %00001
                        byte    %00010
                        byte    %11100
 