CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  '_stack = ($3000 + $3000) >> 2   'accomodate display memory and stack
  '_stack = 6144
  '_stack = ($3000+(1024/4)+100) >> 2

  ButtonPin = 16                
  RTCADDR = $6000        ' Address of real-time clock (updated by subsys)

OBJ

  tel           : "api_telnet_serial"
  term          : "TV_Text"
  timer         : "timer"
  ir            : "ir_reader_sony"
  subsys        : "subsys"
  settings      : "settings"
                                     
VAR
  byte curr_chan

  byte error
  long ircode
  long TMP
  long TMP2


  long in
  long gotstart
  long port

  long weatherstack[40]
  
 
PUB init | i
  outa[0]:=0
  dira[0]:=1
  
  term.start(12)

  term.str(string("ybox2 debug",13,13))

  subsys.init

  subsys.StatusLoading

  ir.init(15, 0, 300, 1)
  settings.start

  'settings.setByte(settings#SOUND_DISABLE,TRUE)
  
  ' Comment out following line to mute
  if settings.findKey(settings#SOUND_DISABLE) == FALSE
    dira[8]:=1
  
  dira[0]:=0

  if not \tel.start(1,2,3,4,6,7,-1,-1)
    subsys.StatusFatalError
    SadChirp
    waitcnt(clkfreq + cnt)
    reboot

  HappyChirp

  if settings.getData(settings#NET_MAC_ADDR,@weatherstack,6)
    term.str(string("MAC: "))
    repeat i from 0 to 5
      if i
        term.out("-")
      term.hex(byte[@weatherstack][i],2)
  term.out(13)  

  main
  
PUB main    
  delay_ms(2000) ' Wait a second to let the ethernet stabalize

  cognew(WeatherUpdate, @weatherstack) 

  repeat while true
    ircode:=ir.fifo_get
    if ircode <> -1
      term.str(string("KC:"))
      term.hex(ircode,2)
      term.str(string(" ID:"))
      term.hex(ir.fifo_get_lastvalid,4)
      term.out(13)
    if ina[ButtonPin]
      subsys.StatusFatalError
      SadChirp
      repeat while ina[ButtonPin]
      subsys.StatusIdle
    if ircode == $0E
      outa[0]:=0
      dira[0]:=1
      subsys.StatusFatalError
      SadChirp
      reboot
    if ircode == $0F
      term.stop
      term.start(12)
    if ircode == $64
      HappyChirp
      SadChirp
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
    

    curr_chan := 0

pub WeatherUpdate | timeout, retrydelay
  port := 20000
  retrydelay := 500
  repeat
  
    if port > 30000
      port := 20000

    tel.connect(208,131,149,67,80,port)
    
    term.str(string($1,$A,39,$C,1," ",$C,$8))
    
    tel.resetBuffers
    
    tel.waitConnectTimeout(2000)
     
    if tel.isConnected

      term.str(string($1,$B,12,"                                       "))
      term.str(string($1,$A,39,$C,$8," ",$1))

      tel.str(string("GET /?id=124932&pass=sunplant HTTP/1.0",13,10))       ' use HTTP/1.0, since we don't support chunked encoding
      tel.str(string("Host: propserve.fwdweb.com",13,10))
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
            term.dec(subsys.RTC)
            delay_ms(30000)     ' 30 sec delay
            subsys.StatusLoading
            quit
          if cnt-timeout>10*clkfreq ' 10 second timeout      
            subsys.StatusFatalError
            term.str(string($1,$B,12,$C,$1,"Error: Connection lost!",$C,$8))       
            tel.close
            ++port ' Change the source port, just in case
            if retrydelay < 10_000
               retrydelay+=retrydelay
            delay_ms(retrydelay)             ' failed to connect     
            quit
    else
      subsys.StatusFatalError
      term.str(string($1,$B,12,$C,$1,"Error: Failed to Connect!",$C,$8))
    
      tel.close
      ++port ' Change the source port, just in case
      if retrydelay < 10_000
         retrydelay+=retrydelay
      delay_ms(retrydelay)             ' failed to connects     

pub HappyChirp

  TMP:=25
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=400
    repeat while TMP2
      TMP2--
  TMP:=30
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=350
    repeat while TMP2
      TMP2--
  TMP:=35
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=300
    repeat while TMP2
      TMP2--
pub SadChirp

  TMP:=35
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=300
    repeat while TMP2
      TMP2--
  TMP:=30
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=350
    repeat while TMP2
      TMP2--
  TMP:=25
  repeat while TMP
    TMP--
    outa[8]:=!outa[8]  
    TMP2:=400
    repeat while TMP2
      TMP2--
PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
DAT
        