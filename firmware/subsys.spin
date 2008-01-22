' This file handles the RGB LED, the piezo speaker, and the
' button watchdog. 
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  LED_RPin = 9
  LED_GPin = 11
  LED_BPin = 10
  BTTNPin = 16
  SPKRPin = 8

VAR
  long LED_R
  long LED_G
  long LED_B
  long TMP
  long TMP2
  long stack[16] 'Stack space for new cog
  byte modecog
PUB init
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
      TMP:=25
      repeat while TMP
        TMP--
    repeat while LED_R
      LED_R--
      TMP:=25
      repeat while TMP
        TMP--
  
PUB LoadingCycle
  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while 1
    repeat while LED_B<>255
      LED_B++
      TMP:=200
      repeat while TMP
        TMP--
    repeat while LED_B
      LED_B--
      TMP:=200
      repeat while TMP
        TMP--

PUB ColorCycle

  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while LED_G<>255
    LED_G++
    TMP:=1000
    repeat while TMP
      TMP--
  repeat while 1
    repeat while LED_G
      LED_G--
      LED_R++
      TMP:=1000
      repeat while TMP
        TMP--
    repeat while LED_R
      LED_B++
      LED_R--
      TMP:=1000
      repeat while TMP
        TMP--
    repeat while LED_B
      LED_G++
      LED_B--
      TMP:=1000
      repeat while TMP
        TMP--
     
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


LEDDutyLoop

              rdbyte T1,LEDRDutyPtr
              shl T1,#23
              add LEDRP,T1 wc
        if_nc jmp #:LEDROff
              or outa,LEDRMask
              jmp #:LEDRDone
:LEDROff
              andn outa,LEDRMask
:LEDRDone              

              rdbyte T1,LEDGDutyPtr
              shl T1,#23
              add LEDGP,T1 wc
        if_nc jmp #:LEDGOff
              or outa,LEDGMask
              jmp #:LEDGDone
:LEDGOff
              andn outa,LEDGMask
:LEDGDone              

              rdbyte T1,LEDBDutyPtr
              shl T1,#23
              add LEDBP,T1 wc
        if_nc jmp #:LEDBOff
              or outa,LEDBMask
              jmp #:LEDBDone
:LEDBOff
              andn outa,LEDBMask
:LEDBDone                  

              jmp #loop


LEDRMask       long (1 << LED_RPin)
LEDGMask       long (1 << LED_GPin)
LEDBMask       long (1 << LED_BPin)

SPKRMask       long (1 << SPKRPin)

RSTCTR        long  %01000_111 << 23 + BTTNPin << 9 + 0
RSTFRQ        long  1
RSTTIME       long  5*80_000_000
RSTCLK        long  -1
T1            res 1

LEDRDutyPtr   res 1
LEDGDutyPtr   res 1
LEDBDutyPtr   res 1

LEDRP         res 1     ' Red Phase
LEDGP         res 1     ' Green Phase
LEDBP         res 1     ' Blue Phase
               