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

  tel           : "api_telnet_serial"
  http          : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  eeprom        : "Basic_I2C_Driver"
  random        : "RealRandom"
                                     
VAR
  long stack[80] 
  byte stage_two
DAT
productName   BYTE      "ybox2 bootloader v0.5",0      
productURL    BYTE      "http://www.deepdarc.com/ybox2/",0

PUB init | i
  'cognew(@bootstage2,0)
  'return
  
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  
  webCog:=0

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
  repeat term#cols/2
    term.out($8E)
    term.out($88)
    'term.out($86)
  term.out($0c)
  term.out(0)
  'term.out(13)
  
  subsys.StatusLoading


  if settings.findKey(settings#MISC_STAGE_TWO)
    stage_two := TRUE
    settings.removeKey(settings#MISC_STAGE_TWO)
  else
    stage_two := FALSE

  if settings.findKey(settings#MISC_AUTOBOOT)
    delay_ms(2000)
    if NOT ina[subsys#BTTNPin]
      boot_stage2

  if NOT settings.size
    if NOT \initial_configuration
      showMessage(string("Initial configuration failed!"))
      subsys.StatusFatalError
      SadChirp
      waitcnt(clkfreq*100000 + cnt)
      reboot

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

  if not \tel.start(1,2,3,4,6,7,-1,-1)
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

  if stage_two
    repeat i from 0 to 255
      subsys.StatusSolid(i,i,i)
      delay_ms(5)
  else
    subsys.StatusIdle
 

  'webCog := cognew(httpInterface, @stack) + 1 
  httpInterface
  'repeat
  '  \downloadFirmware
  '  tel.close
  '  subsys.StatusFatalError
  '  SadChirp
  '  delay_ms(1000)
  
PRI boot_stage2 | i
  settings.setByte(settings#MISC_STAGE_TWO,TRUE)
  repeat i from 0 to 7
    if cogid<>i
      cogstop(i)
  'subsys.stop
  'settings.stop
  'term.stop
  'tel.stop
  ' Replace this cog with the bootloader
  coginit(0,@bootstage2,0)
  cogstop(cogid)
PRI initial_configuration | i
  term.str(string("First boot!",13))

  random.start

  ' Make a random UUID
  repeat i from 0 to 16
    byte[@stack][i] := random.random
  settings.setData(settings#MISC_UUID,@stack,16)

  ' Make a random MAC Address
  byte[@stack][0] := $02
  repeat i from 1 to 5
    byte[@stack][i] := random.random
  settings.setData(settings#NET_MAC_ADDR,@stack,6)

  random.stop

  'settings.setString(settings#MISC_PASSWORD,string("password"))  

  
  ' Uncomment and change these settings if you don't want to use DHCP
  {
  settings.setByte(settings#NET_DHCP_DISABLE,TRUE)
  settings.setData(settings#NET_IPv4_ADDR,string(192,168,2,10),4)
  settings.setData(settings#NET_IPv4_MASK,string(255,255,255,0),4)
  settings.setData(settings#NET_IPv4_GATE,string(192,168,2,1),4)
  settings.setData(settings#NET_IPv4_DNS,string(4,2,2,4),4)
  }

  ' If you want sound off by default, uncomment the next line
  'settings.setByte(settings#SOUND_DISABLE,TRUE)

  'settings.setByte(settings#MISC_AUTOBOOT,TRUE)

  ' RGB LED Configuration
  ' Original board = $000A0B09
  ' Adafruit board = $01090A0B
  'settings.setLong(settings#MISC_LED_CONF,$01090A0B)

  settings.commit
  return TRUE
  
VAR
  byte buffer [128]
  byte buffer2 [128]
  byte webCog
  byte httpQuery[8]
  byte httpPath[64]
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

pub httpInterface | char, i, lineLength,contentSize
  webCog:=cogid+1

  repeat
    repeat while \http.listen(80) == -1
      term.str(string("No free sockets",13))
      if ina[subsys#BTTNPin]
        boot_stage2
      delay_ms(2000)
      http.closeall
      next
    http.resetBuffers
    contentSize:=0
    repeat while NOT http.isConnected
      http.waitConnectTimeout(100)
      if ina[subsys#BTTNPin]
        boot_stage2
    i:=0

    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<7
      httpQuery[i]:=char
      if httpQuery[i] == " "
        quit
      i++
    httpQuery[i]:=0
    term.str(string("HTTP "))
    term.str(@httpQuery)
    term.out(" ")
    i:=0
    repeat while ((char:=http.rxtime(1000)) <> -1) AND (NOT http.isEOF) AND i<63
      httpPath[i]:=char
      if httpPath[i] == " " OR httpPath[i] == "?"
        quit
      i++
    httpPath[i]:=0

    term.str(@httpPath)
    term.out(13)

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
                'content size!
                term.str(string("contentSize:"))
                contentSize := http.readDec
                term.dec(contentSize)
                term.out(13)
                lineLength:=1
          lineLength++
             
    if strcomp(@httpQuery,string("GET"))
      if strcomp(@httpPath,string("/"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<html><body><h1>"))
        http.str(@productName)
        http.str(string("</h1><hr />"))
        http.str(string("<h2>Info</h2>"))
        if settings.getData(settings#NET_MAC_ADDR,@httpQuery,6)
          http.str(string("<div><tt>MAC: "))
          repeat i from 0 to 5
            if i
              http.tx("-")
            http.hex(byte[@httpQuery][i],2)
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

        http.str(string("<div><tt>Autoboot: "))
        if settings.findKey(settings#MISC_AUTOBOOT)  
          http.str(string("<b>ON</b> (<a href='/disable_autoboot'>disable</a>)"))
        else
          http.str(string("<b>OFF</b> (<a href='/enable_autoboot'>enable</a>)"))
        http.str(string("</tt></div>"))
        
        http.str(string("<h2>Actions</h2>"))
        http.str(string("<div><a href='/reboot'>Reboot</a></div>"))
        http.str(string("<div><a href='/stage2'>Boot Stage 2</a></div>"))

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
      elseif strcomp(@httpPath,string("/stage2"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(string("<h1>Booting to stage 2</h1>",13,10))
        delay_ms(1000)
        http.close
        delay_ms(1000)
        boot_stage2
      elseif strcomp(@httpPath,string("/enable_autoboot"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        settings.removeKey($1010)
        settings.setByte(settings#MISC_AUTOBOOT,1)
        settings.commit
        http.str(string("<h1>Autoboot enabled.</h1>",13,10))
      elseif strcomp(@httpPath,string("/disable_autoboot"))
        http.str(@HTTP_303)
        http.str(string("Location: /",13,10))
        http.str(@HTTP_CONTENT_TYPE_HTML)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        settings.removeKey($1010)
        settings.removeKey(settings#MISC_AUTOBOOT)
        settings.commit
        http.str(string("<h1>Autoboot disabled.</h1>",13,10))
      elseif strcomp(@httpPath,string("/ramimage.bin"))
        http.str(@HTTP_200)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        repeat i from 0 to $7FFF
          http.tx(BYTE[i])
      else           
        http.str(@HTTP_404)
        http.str(@HTTP_CONNECTION_CLOSE)
        http.str(@CR_LF)
        http.str(@HTTP_404)
    elseif strcomp(@httpQuery,string("PUT"))
      if not contentSize
          http.str(@HTTP_411)
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(@HTTP_411)
      if strcomp(@httpPath,string("/stage2.bin"))
        http.rxtime(1000)
        if (i:=\downloadFirmwareHTTP(contentSize))
          SadChirp
          http.str(string("HTTP/1.1 400 Bad Request",13,10))
          http.str(@HTTP_CONTENT_TYPE_HTML)
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(string("<h1>Upload failed.</h1>",13,10))
          http.dec(i)         
        else
          http.str(@HTTP_303)
          http.str(string("Location: /",13,10))
          http.str(@HTTP_CONTENT_TYPE_HTML)
          http.str(@HTTP_CONNECTION_CLOSE)
          http.str(@CR_LF)
          http.str(string("<h1>Upload complete.</h1>",13,10))
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
    
    'delay_ms(1500)    
    http.close
    term.str(string(13,"HTTP Closed",13))


pub downloadFirmwareHTTP(contentSize) | timeout, retrydelay,in, i, total, addr,j
  eeprom.Initialize(eeprom#BootPin)

  i:=0
  total:=0
  
  if stage_two
    addr:=$0000 ' Stage two writes to the lower 32KB
  else
    addr:=$8000 ' Stage one writes to the upper 32KB

  if contentSize > $8000-settings#SettingsSize
    contentSize:=$8000-settings#SettingsSize
   
  repeat
    if (in := http.rxcheck) => 0
      subsys.StatusSolid(0,128,0)
      buffer[i++] := in
      if i == 128
        ' flush to EEPROM                              
        subsys.StatusSolid(0,0,128)
        if stage_two
          'Verify that the bytes we got match the EEPROM
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
            abort -1
          repeat i from 0 to 127
            if buffer[i] <> buffer2[i]
              abort -2
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort -3
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
        total+=i
        i:=0
        bytefill(@buffer,0,128)
        
        term.out(".")
      if total => $8000-settings#SettingsSize
        http.close
    else
      subsys.StatusSolid(128,0,0)
      if http.isEOF OR (total+i) => contentSize
        if stage_two
          ' Do we have the correct number of bytes?
          if settings.findKey($1010) AND ((total+i) <> settings.getWord($1010))
            SadChirp
            term.dec((total+i) - settings.getWord($1010))
            term.str(string(" byte diff!",13))
            abort -4                     

          'Verify that the bytes we got match the EEPROM
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
            abort -1
          repeat j from 0 to i-1
            if buffer[j] <> buffer2[j]
              abort -5

          total+=i

          'If we got to this point, then everything matches! Write it out
          subsys.StatusLoading
          HappyChirp
          
          term.str(string("verified!",13))

          term.str(string("Writing"))

          repeat i from 0 to total-1 step 128
            if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
              abort -6
            if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, i, @buffer, 128)
              abort -7
            repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, i)
            term.out(".")
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort -8
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
          total+=i
        
        ' done!
        term.str(string("done.",13))
        term.dec(total)
        term.str(string(" bytes written",13))
        HappyChirp
        subsys.StatusSolid(0,255,0)
        settings.setWord($1010,total)
        return 0
        'delay_ms(5000)     ' 5 sec delay



  return 0

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
  
DAT
        org
' Taken from the propeller booter code, supplied by Parallax.

' Load ram from eeprom and launch
'
bootstage2              
                        clkset  zero
                        mov     raddress,zero
                        call    #ee_read                'send read command
:loop                   call    #ee_receive             'get eeprom byte
                        wrbyte  eedata,raddress          'write to ram
                        add     address,#1              'inc address
                        add     raddress,#1              'inc address
                        djnz    count,#:loop            'loop until done
                        call    #ee_stop                'end read (followed by launch)
'
'
' Launch program in ram
'
launch                  rdword  address,#$0004+2        'if pbase address invalid, shutdown
                        cmp     address,#$0010  wz
        if_nz           jmp     #shutdown

                        rdbyte  address,#$0004          'if xtal/pll enabled, start up now
                        and     address,#$F8            '..while remaining in rcfast mode
                        clkset  address

:delay                  djnz    time_xtal,#:delay       'allow 20ms @20MHz for xtal/pll to settle

                        rdbyte  address,#$0004          'switch to selected clock
                        clkset  address

                        coginit interpreter             'reboot cog with interpreter

                        ' Stop this cog.
                        cogid   address
                        cogstop address
'
'
' Shutdown
'
shutdown
                        'jmp shutdown
                        'mov     smode,#$1FF              'reboot actualy
                        mov     smode,#$02              'reboot actualy
                        clkset  smode                   '(reboot)
'                       
'
'**************************************
'* I2C routines for 24x256/512 EEPROM *
'* assumes fastest RC timing - 20MHz  *
'*   SCL low time  =  8 inst, >1.6us  *
'*   SCL high time =  4 inst, >0.8us  *
'*   SCL period    = 12 inst, >2.4us  *
'**************************************
'
'
' Begin eeprom read
'
ee_read                 mov     address,h8000           'reset address to $8000, the upper half of the EEPROM

                        call    #ee_write               'begin write (sets address)

                        mov     eedata,#$A1             'send read command
                        call    #ee_start
        if_c            jmp     #shutdown               'if no ack, shutdown

                        mov     count,programsize             'set count to programsize

ee_read_ret             ret
'
'
' Begin eeprom write
'
ee_write                call    #ee_wait                'wait for ack and begin write

                        mov     eedata,address          'send high address
                        shr     eedata,#8
                        call    #ee_transmit
        if_c            jmp     #shutdown               'if no ack, shutdown

                        mov     eedata,address          'send low address
                        call    #ee_transmit
        if_c            jmp     #shutdown               'if no ack, shutdown

ee_write_ret            ret
'
'
' Wait for eeprom ack
'
ee_wait                 mov     count,#400              '       400 attempts > 10ms @20MHz
:loop                   mov     eedata,#$A0             '1      send write command
                        call    #ee_start               '132+
        if_c            djnz    count,#:loop            '1      if no ack, loop until done

        if_c            jmp     #shutdown               '       if no ack, shutdown

ee_wait_ret             ret
'
'
' Start + transmit
'
ee_start                mov     bits,#9                 '1      ready 9 start attempts
:loop                   andn    outa,mask_scl           '1(!)   ready scl low
                        or      dira,mask_scl           '1!     scl low
                        nop                             '1
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay5                 '5
                        or      outa,mask_scl           '1!     scl high
                        nop                             '1
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

        if_nc           jmp     #shutdown               '1      if sda still not high, shutdown

                        or      dira,mask_sda           '1!     sda low
'
'
' Transmit/receive
'
ee_transmit             shl     eedata,#1               '1      ready to transmit byte and receive ack
                        or      eedata,#%00000000_1     '1
                        jmp     #ee_tr                  '1

ee_receive              mov     eedata,#%11111111_0     '1      ready to receive byte and transmit ack

ee_tr                   mov     bits,#9                 '1      transmit/receive byte and ack
:loop                   test    eedata,#$100    wz      '1      get next sda output state
                        andn    outa,mask_scl           '1!     scl low
                        rcl     eedata,#1               '1      shift in prior sda input state
                        muxz    dira,mask_sda           '1!     sda low/float
                        call    #delay4                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
                        or      outa,mask_scl           '1!     scl high
                        nop                             '1
                        djnz    bits,#:loop             '1,2    if another bit, loop

                        and     eedata,#$FF             '1      isolate byte received
ee_receive_ret
ee_transmit_ret
ee_start_ret            ret                             '1      nc=ack
'
'
' Stop
'
ee_stop                 mov     bits,#9                 '1      ready 9 stop attempts
:loop                   andn    outa,mask_scl           '1!     scl low
                        nop                             '1
                        or      dira,mask_sda           '1!     sda low
                        call    #delay5                 '5
                        or      outa,mask_scl           '1!     scl high
                        call    #delay3                 '3
                        andn    dira,mask_sda           '1!     sda float
                        call    #delay4                 '4
                        test    mask_sda,ina    wc      'h?h    sample sda
        if_nc           djnz    bits,#:loop             '1,2    if sda not high, loop until done

ee_jmp  if_nc           jmp     #shutdown               '1      if sda still not high, shutdown

ee_stop_ret             ret                             '1
'
'
' Cycle delays
'
delay5                  nop                             '1
delay4                  nop                             '1
delay3                  nop                             '1
delay2
delay2_ret
delay3_ret
delay4_ret
delay5_ret              ret                             '1

'
'
' Constants
'
mask_rx                 long    $80000000
mask_tx                 long    $40000000
mask_sda                long    $20000000
mask_scl                long    $10000000
time                    long    150 * 20000 / 4 / 2     '150ms (@20MHz, 2 inst/loop)
time_load               long    100 * 20000 / 4 / 2     '100ms (@20MHz, 2 inst/loop)
time_xtal               long    20 * 20000 / 4 / 1      '20ms (@20MHz, 1 inst/loop)
lfsr                    long    "P"
zero                    long    0
smode                   long    0
hFFF9FFFF               long    $FFF9FFFF
h8000                   long    $8000
programsize             long    $8000-settings#SettingsSize
interpreter             long    $0001 << 18 + $3C01 << 4 + %0000
'
'
' Variables
'
command                 res     1
address                 res     1
raddress                res     1
count                   res     1
bits                    res     1
eedata                  res     1
rxdata                  res     1
delta                   res     1
threshold               res     1