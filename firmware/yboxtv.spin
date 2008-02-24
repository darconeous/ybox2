CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  '_stack = ($3000 + $3000) >> 2   'accomodate display memory and stack
  '_stack = 6144
  '_stack = ($3000+(1024/4)+100) >> 2

  ButtonPin = 16                
                                     
VAR



  byte curr_chan

  byte button_pushed
  byte flickr_mode
  word flasher
  byte error
  long ircode
  long TMP
  long TMP2


  long in
  long gotstart
  long port

  long weatherstack[30]
  
OBJ

  term          : "TV_Text"
  timer         : "timer"
  ir            : "ir_reader_sony"
  subsys        : "subsys"
   tel : "api_telnet_serial"
 
PUB init
  outa[0]:=0
  dira[0]:=1
  
  term.start(12)

  term.str(@title)

  subsys.init

  subsys.StatusLoading

  'error:=ir.init(15, $093A, 300, 1)
  error:=ir.init(15, 0, 300, 1)
  
  ' Comment out following line to mute
  'dira[8]:=1
  
  dira[0]:=0

  tel.start(1,2,3,4,6,7,-1,-1)

  HappyChirp

  term.out(13)  

  main
  
PUB main    
  delay_ms(1000)

  cognew(WeatherUpdate, @weatherstack) 


  repeat while true
    ircode:=ir.fifo_get
    if ircode <> -1
      term.out("K")
      term.out("C")
      term.out(":")
      term.hex(ircode,2)
      term.out(" ")
      term.out("I")
      term.out("D")
      term.out(":")
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

pub WeatherUpdate 
  port := 20000
  repeat
  
    if port > 30000
      port := 20000

    ++port
    

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
      repeat
        if (in := tel.rxcheck) > 0
 
          if gotstart AND in <> 10
            term.out(in)

          if in == $01
            gotstart := true
        else
          ifnot tel.isConnected
            subsys.StatusIdle
            delay_ms(30000)     ' 30 sec delay
            subsys.StatusLoading
            quit
            
    else
      subsys.StatusFatalError
      term.str(string($1,$B,12,$C,$1,"Error: Failed to Connect!",$C,$8))
    
      tel.close
      delay_ms(100)             ' failed to connect, try again in 100ms     

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
title   byte    "ybox2 Debug",13,13,0
irstart byte   "Starting ir...",0
ethstart byte   "Starting ethernet...",0
stat_fail byte   "FAIL",0
stat_ok byte   "OK",0
        ETH_MAC         byte    $10, $00, $00, $00, $00, $01
        