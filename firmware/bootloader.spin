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
  term          : "TV_Text"
  subsys        : "subsys"
  settings      : "settings"
  eeprom        : "Basic_I2C_Driver"
  random        : "RealRandom"
                                     
VAR
  byte stack[40] 
  
PUB init | i
  'cognew(@bootstage2,0)
  'return
  
  outa[0]:=0
  dira[0]:=1
  dira[subsys#SPKRPin]:=1
  

  subsys.init
  term.start(12)
  term.str(string(13,"ybox2 bootloader",13,"http://www.deepdarc.com/ybox2/",13,13))

  subsys.StatusLoading

  settings.start

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

{
  repeat i from 0 to 127
    if i
      term.out(" ")
    term.hex(byte[$7F80][i],2)
  term.out(13)  
  waitcnt(clkfreq*100000 + cnt)
}
   
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
   
  downloadFirmware
  
PRI boot_stage2
  subsys.stop
  settings.stop
  term.stop
  tel.stop
  ' Replace this cog with the bootloader
  coginit(cogid,@bootstage2,0)
PRI initial_configuration | i
  term.str(string("First boot!",13))

  random.start

  ' Make a random UUID
  repeat i from 0 to 16
    stack[i] := random.random
  settings.setData(settings#MISC_UUID,@stack,16)

  ' Make a random MAC Address
  stack[0] := $02
  repeat i from 1 to 5
    stack[i] := random.random
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

  settings.commit
  return TRUE
  
VAR
  byte buffer [128]
  
pub downloadFirmware | timeout, retrydelay,in, i, total, addr
  term.str(string("Listening on port 72",13))

  eeprom.Initialize(eeprom#BootPin)

  
  tel.listen(72)
  tel.resetBuffers
  
  repeat while NOT tel.isConnected
    tel.waitConnectTimeout(100)
    if ina[subsys#BTTNPin]
      boot_stage2
      
  term.str(string("Connected",13))

  tel.str(string("ybox2",13))

  i:=0
  total:=0
  addr:=$8000
  repeat
    if (in := tel.rxcheck) => 0
      buffer[i++] := in
      if i == 128
        ' flush to EEPROM                              
        if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            term.out("E")
        repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
        total+=i
        i:=0
        term.out(".")
      if total => $8000-settings#SettingsSize
        tel.close
    else
      ifnot tel.isConnected OR total => $8000-settings#SettingsSize
        if \eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, total+addr, @buffer, 128)
            term.out("E")
        repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, total)
        total+=i

        ' done!
        term.str(string("done.",13))
        term.dec(total)
        term.str(string(" bytes written"))
        delay_ms(5000)     ' 5 sec delay
        boot_stage2

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

                        mov     count,h8000             'set count to $8000

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