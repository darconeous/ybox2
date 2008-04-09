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
  timer         : "timer"
  ir            : "ir_reader_sony"
  subsys        : "subsys"
  settings      : "settings"
                                     
VAR
  long weatherstack[40] 
  byte path_holder[64]
  
PUB init | i
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
  settings.start
  subsys.init
  term.start(12)
  term.str(string(13,"ybox2",13,"http://www.deepdarc.com/ybox2/",13,13))

  subsys.StatusLoading

  ir.init(15, 0, 300, 1)

  if NOT settings.findKey(settings#MISC_CONFIGURED_FLAG)
    if NOT \initial_configuration
      showMessage(string("Initial configuration failed!"))
      subsys.StatusFatalError
      SadChirp
      waitcnt(clkfreq*10000 + cnt)
      reboot
         
  if settings.findKey(settings#SOUND_DISABLE) == FALSE
    dira[subsys#SPKRPin]:=1
  else
    dira[subsys#SPKRPin]:=0
  
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
  term.str(string("First boot!",13))

  ' Mark outselves as configured so we know we don't have to repeat this step.
  settings.setByte(settings#MISC_CONFIGURED_FLAG,TRUE)

  settings.setString(settings#MISC_PASSWORD,string("password"))  

  ' If the mac address is left undefined, a random
  ' one will be chosen on the first boot. This is
  ' safe to leave commented out.
  settings.setData(settings#NET_MAC_ADDR,string($02, $FF, $DE, $AD, $BE, $EF),6)

  ' Uncomment and change these settings if you don't want to use DHCP
  {
  settings.setByte(settings#NET_DHCP_DISABLE,TRUE)
  settings.setData(settings#NET_IPv4_ADDR,string(192,168,2,10),4)
  settings.setData(settings#NET_IPv4_MASK,string(255,255,255,0),4)
  settings.setData(settings#NET_IPv4_GATE,string(192,168,2,1),4)
  settings.setData(settings#NET_IPv4_DNS,string(4,2,2,4),4)
  }

  ' If you want sound off by default, uncomment the next line
  settings.setByte(settings#SOUND_DISABLE,TRUE)
  
  settings.setString(settings#SERVER_HOST,string("propserve.fwdweb.com"))  
  settings.setData(settings#SERVER_IPv4_ADDR,string(208,131,149,67),4)
  settings.setWord(settings#SERVER_IPv4_PORT,80)
  settings.setString(settings#SERVER_PATH,string("/?id=124932&pass=sunplant"))

  settings.commit
  return TRUE
  
PUB main | ircode
  delay_ms(2000) ' Wait a second to let the ethernet stabalize

  cognew(WeatherUpdate, @weatherstack) 

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
      if settings.findKey(settings#SOUND_DISABLE) == FALSE
        showMessage(string("[MUTED]"))    
        settings.setByte(settings#SOUND_DISABLE,TRUE)
        dira[subsys#SPKRPin]:=0       
        settings.commit
        ir.fifo_flush
      else
        showMessage(string("[UNMUTED]"))    
        settings.removeData(settings#SOUND_DISABLE)
        dira[subsys#SPKRPin]:=1       
        HappyChirp
        settings.commit
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
     
    if tel.isConnected

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

pub HappyChirp | TMP,TMP2

  TMP:=25
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=400
    repeat while TMP2
      TMP2--
  TMP:=30
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=350
    repeat while TMP2
      TMP2--
  TMP:=35
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=300
    repeat while TMP2
      TMP2--
pub SadChirp | TMP,TMP2

  TMP:=35
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=300
    repeat while TMP2
      TMP2--
  TMP:=30
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=350
    repeat while TMP2
      TMP2--
  TMP:=25
  repeat while TMP
    TMP--
    outa[subsys#SPKRPin]:=!outa[subsys#SPKRPin]  
    TMP2:=400
    repeat while TMP2
      TMP2--
PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
     