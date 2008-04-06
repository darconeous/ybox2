{{
        ybox2 - subsys object
        http://www.deepdarc.com/ybox2

        This file handles the RGB LED, the piezo speaker, and the
        button watchdog.
        Also includes a RTC.
}} 
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  LED_CA = 0 ' 1 = Common Anode, 0 = Common Cathode
  LED_RPin = 9
  LED_GPin = 11
  LED_BPin = 10

  BTTNPin = 16
  SPKRPin = 8
  RTCADDR = $6000
VAR
  long LED_R
  long LED_G
  long LED_B
  long TMP
  long TMP2
  long stack[16] 'Stack space for new cog
  byte modecog
PUB init
  'long[RTCADDR]:=1
  cognew(@run, @LED_R) 
  StatusIdle

PUB Stop
  if modecog
    cogstop(modecog~ - 1)
  
PUB StatusIdle
  stop
  modecog := cognew(ColorCycle, @stack) + 1 
PUB StatusLoading
  stop
  modecog := cognew(LoadingCycle, @stack) + 1 

PUB StatusFatalError
  stop
  modecog := cognew(FatalErrorCycle, @stack) + 1 
PUB FatalErrorCycle
  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while 1
    repeat while LED_R<>255
      LED_R++
      waitcnt(20_000 + cnt)
    repeat while LED_R
      LED_R--
      waitcnt(20_000 + cnt)
  
PUB LoadingCycle
  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while 1
'    long[RTCADDR]++
    repeat while LED_B<>255
      LED_B++
      waitcnt(100_000 + cnt)
    repeat while LED_B
      LED_B--
      waitcnt(100_000 + cnt)

PUB ColorCycle

  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while LED_G<>255
    LED_G++
    waitcnt(400_000 + cnt)
  repeat while 1
    repeat while LED_G
      LED_G--
      LED_R++
      waitcnt(400_000 + cnt)
    repeat while LED_R
      LED_B++
      LED_R--
      waitcnt(400_000 + cnt)
    repeat while LED_B
      LED_G++
      LED_B--
      waitcnt(400_000 + cnt)
PUB RTC
  return long[RTCADDR]
      
DAT

              org

run
              mov T1,par
              mov LEDRDutyPtr,T1
              add T1,#4
              mov LEDGDutyPtr,T1
              add T1,#4
              mov LEDBDutyPtr,T1

              ' Set the directions on the pins we control
              or dira,LEDRMask
              or dira,LEDGMask
              or dira,LEDBMask
              or dira,SPKRMask


              ' Set up CTRA for the button watchdog.
              mov phsa,#0
              mov ctra,RSTCTR
              mov frqa,RSTFRQ

              ' Set up RTCLAST for RTC
              rdlong RTCLAST,#0
              add RTCLAST, cnt
              
loop

              ' If the button was released,
              ' reset the phase register.
              mov  T1,#1
              shl  T1,#BTTNPin
              test T1,ina wz
        if_z  mov phsa,#0


              ' If the button has been held down more
              ' than 5 seconds, then reset the board.
              cmp  RSTTIME,phsa wc
        if_c  clkset RSTCLK

              'rdlong T1,RTCPTR
              'mov T1,#%111111111
              'wrlong T1,RTCPTR

              'rdlong T1,RTCPTR
              'add T1,#1
              'wrlong T1,RTCPTR

LEDDutyLoop

              rdbyte T1,LEDRDutyPtr
              shl T1,#23
              add LEDRP,T1 wc
              long %010111_0001_0011_000000000_000000000 + :LEDROff + (LED_CA * %1001_000000000_000000000)
'        if_nc jmp #:LEDROff
              or outa,LEDRMask
              jmp #:LEDRDone
:LEDROff
              andn outa,LEDRMask
:LEDRDone              

              rdbyte T1,LEDGDutyPtr
              shl T1,#23
              add LEDGP,T1 wc
              long %010111_0001_0011_000000000_000000000 + :LEDGOff + (LED_CA * %1001_000000000_000000000)
'        if_nc jmp #:LEDGOff
              or outa,LEDGMask
              jmp #:LEDGDone
:LEDGOff
              andn outa,LEDGMask
:LEDGDone              

              rdbyte T1,LEDBDutyPtr
              shl T1,#23
              add LEDBP,T1 wc
              long %010111_0001_0011_000000000_000000000 + :LEDBOff + (LED_CA * %1001_000000000_000000000)
'        if_nc jmp #:LEDBOff
              or outa,LEDBMask
              jmp #:LEDBDone
:LEDBOff
              andn outa,LEDBMask
:LEDBDone                  


              ' Update the RTC
              rdlong T1,#0
              mov T2,RTCLAST
              sub T2,cnt
              cmp T1,T2 wc
        if_nc jmp #loop
              add RTCLAST,T1
              rdlong T1,RTCPTR
              add T1,#1
              wrlong T1,RTCPTR
              jmp #loop
              


LEDRMask      long (1 << LED_RPin)
LEDGMask      long (1 << LED_GPin)
LEDBMask      long (1 << LED_BPin)

SPKRMask      long (1 << SPKRPin)

RSTCTR        long  %01000_111 << 23 + BTTNPin << 9 + 0
RSTFRQ        long  1
RSTTIME       long  5*80_000_0000
RSTCLK        long  -1
RTCPTR        long RTCADDR
RTCLAST       res 1

T1            res 1
T2            res 1

LEDRDutyPtr   res 1
LEDGDutyPtr   res 1
LEDBDutyPtr   res 1

LEDRP         res 1     ' Red Phase
LEDGP         res 1     ' Green Phase
LEDBP         res 1     ' Blue Phase

              FIT
              
         