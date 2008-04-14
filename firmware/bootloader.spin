{{
        ybox2 - bootloader object
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
  http          : "api_telnet_serial"
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  eeprom        : "Basic_I2C_Driver"
  random        : "RealRandom"
                                     
VAR
  long stack[40] 
  byte stage_two
  
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
  term.str(string(13,"ybox2 bootloader",13,"http://www.deepdarc.com/ybox2/",13,13))

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
    term.str(string("Waiting for IP address...",13))
    repeat while NOT settings.getData(settings#NET_IPv4_ADDR,@stack,4)
      delay_ms(500)

  term.str(string("IPv4 ADDR:"))
  repeat i from 0 to 3
    if i
      term.out(".")
    term.dec(byte[@stack][i])
  term.out(13)  

  if settings.getData(settings#NET_IPv4_DNS,@stack,4)
    term.str(string("DNS ADDR:"))
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
  'httpInterface
  repeat
    \downloadFirmware
    tel.close
    subsys.StatusFatalError
    SadChirp
    delay_ms(1000)
  
PRI boot_stage2
  settings.setByte(settings#MISC_STAGE_TWO,TRUE)
  subsys.stop
  settings.stop
  term.stop
  tel.stop
  'if(webCog)
  '  cogstop(webCog)
  ' Replace this cog with the bootloader
  coginit(cogid,@bootstage2,0)
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

  settings.setString(settings#MISC_PASSWORD,string("password"))  

  
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
  
pub httpInterface
  webCog:=cogid+1

  repeat
    http.listen(80)
    http.resetBuffers

    repeat while NOT http.isConnected
      http.waitConnectTimeout(100)
  
    http.str(string("Proshki!",13))
    delay_ms(500)    
    http.close
  
pub downloadFirmware | timeout, retrydelay,in, i, total, addr,j
  term.str(string("Listening on port 72",13))

  eeprom.Initialize(eeprom#BootPin)

  
  tel.listen(72)
  tel.resetBuffers
  
  repeat while NOT tel.isConnected
    tel.waitConnectTimeout(100)
    if ina[subsys#BTTNPin]
      boot_stage2

  subsys.StatusLoading
    
  term.str(string("Connected",13))

  tel.str(string("ybox2",13))

  i:=0
  total:=0
  
  if stage_two
    addr:=$0000 ' Stage two writes to the lower 32KB
  else
    addr:=$8000 ' Stage one writes to the upper 32KB
  
  repeat
    if (in := tel.rxcheck) => 0
      buffer[i++] := in
      if i == 128
        ' flush to EEPROM                              
        if stage_two
          'Verify that the bytes we got match the EEPROM
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
            abort
          repeat i from 0 to 127
            if buffer[i] <> buffer2[i]
              abort
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
        total+=i
        i:=0
        term.out(".")
      if total => $8000-settings#SettingsSize
        tel.close
    else
      ifnot tel.isConnected OR total => $8000-settings#SettingsSize
        if stage_two
          'Verify that the bytes we got match the EEPROM
          if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, total+$8000, @buffer2, 128)
            abort
          repeat j from 0 to i-1
            if buffer[j] <> buffer2[j]
              abort

          total+=i
          if settings.findKey($1010) AND (total <> settings.getWord($1010))
            abort                      

          'If we got to this point, then everything matches! Write it out
          HappyChirp

          term.str(string("verified!",13))

          ' Kill the network, just to make sure it doesn't interfere
          tel.close
          delay_ms(250)
          tel.stop
          delay_ms(250)

          term.str(string("Writing"))

          repeat i from 0 to total-1 step 128
            if \eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, i+$8000, @buffer, 128)
              abort
            if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, i, @buffer, 128)
              abort
            repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, i)
            term.out(".")
        else
          if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            abort
          repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
          total+=i

        ' done!
        term.str(string("done.",13))
        term.dec(total)
        term.str(string(" bytes written"))
        HappyChirp
        subsys.StatusSolid(0,255,0)
        settings.setWord($1010,total)
        delay_ms(5000)     ' 5 sec delay
        if stage_two
          reboot
        else
          boot_stage2

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