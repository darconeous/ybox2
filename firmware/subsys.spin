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
  LED_CA = 1 ' 1 = Common Anode, 0 = Common Cathode
  LED_RPin = 9
  LED_GPin = 10
  LED_BPin = 11
  LED_Brightness = 8 ' 0 = least bright, 8 = most bright
  BTTNPin = 16
  SPKRPin = 8
  RTCADDR = $7A00
DAT
TMP     long 0
TMP2    long 0
LED_R   byte 0
LED_G   byte 0
LED_B   byte 0
modecog byte 0
subsyscog byte 0
OBJ
  settings      : "settings"
VAR
  long stack[16] 'Stack space for new cog
PUB init | LED_Conf
  if settings.getData(settings#MISC_LED_CONF,@LED_Conf,4) == 4
    ' We have custom LED settings!
    ' Update the LED masks
    LEDRMask:=1<<BYTE[@LED_Conf][0]
    LEDGMask:=1<<BYTE[@LED_Conf][1]
    LEDBMask:=1<<BYTE[@LED_Conf][2]
    if BYTE[@LED_Conf][3]
      LEDRJmp ^= %1111_000000000_000000000 ' Invert Red output
      LEDGJmp ^= %1111_000000000_000000000 ' Invert Green Output
      LEDBJmp ^= %1111_000000000_000000000 ' Invert Blue Output
  else
    if LED_CA
      LEDRJmp ^= %1111_000000000_000000000 ' Invert Red output
      LEDGJmp ^= %1111_000000000_000000000 ' Invert Green Output
      LEDBJmp ^= %1111_000000000_000000000 ' Invert Blue Output
       
  subsyscog := cognew(@run, @LED_R)+1 
  StatusIdle

PUB Stop
  if subsyscog
    cogstop(subsyscog~ - 1)
    subsyscog:=0
  StatusOff
  if modecog
    cogstop(modecog~ - 1)
    modecog:=0
PUB StatusOff
  if modecog
    cogstop(modecog~ - 1)
    modecog:=0
PUB irTest
  StatusOff
  modecog := cognew(irTestCycle, @stack) + 1 

PRI irTestCycle
  LED_R:=0
  LED_G:=0
  LED_B:=255
  repeat
    waitpeq(FALSE,1<<15,0)
    LED_R:=255
    LED_G:=255
    LED_B:=0
    waitpne(FALSE,1<<15,0)
    LED_R:=0
    LED_G:=0
    LED_B:=255

PUB StatusIdle
  StatusOff
  modecog := cognew(ColorCycle, @stack) + 1 
PUB StatusLoading
  StatusOff
  modecog := cognew(LoadingCycle, @stack) + 1 

PUB StatusFatalError
  StatusOff
  modecog := cognew(FatalErrorCycle, @stack) + 1 
PUB StatusError
  StatusOff
  modecog := cognew(FatalErrorCycle, @stack) + 1
PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  
   
pub ChirpHappy | i, j
  repeat j from 0 to 2
    repeat i from 0 to 30
      outa[SPKRPin]:=!outa[SPKRPin]  
      delay_ms(1)
    outa[SPKRPin]:=0  
    delay_ms(50)
pub ChirpSad | i
  repeat i from 0 to 15
    outa[SPKRPin]:=!outa[SPKRPin]  
    delay_ms(17)
  outa[SPKRPin]:=0

PUB StatusSolid(r,g,b)
  StatusOff
  LED_R:=r
  LED_G:=g
  LED_B:=b
PUB FatalErrorCycle
  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while 1
    repeat LED_R from 0 to 254
      waitcnt(20_000 + cnt)
    repeat LED_R from 255 to 1
      LED_R--
      waitcnt(20_000 + cnt)
  
PUB LoadingCycle
  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat while 1
    repeat LED_B from 0 to 254
      waitcnt(100_000 + cnt)
    repeat LED_B from 255 to 1
      waitcnt(100_000 + cnt)

PUB ColorCycle

  LED_R:=0
  LED_G:=0
  LED_B:=0
  repeat LED_G from 0 to 254
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
              add T1,#1
              mov LEDGDutyPtr,T1
              add T1,#1
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


LEDDutyLoop

              rdbyte T1,LEDRDutyPtr
              shl T1,LEDBright
              add LEDRP,T1 wc
LEDRJmp       long %010111_0001_0011_000000000_000000000 + :LEDROff
'        if_nc jmp #:LEDROff
              or outa,LEDRMask
              jmp #:LEDRDone
:LEDROff
              andn outa,LEDRMask
:LEDRDone              

              rdbyte T1,LEDGDutyPtr
              shl T1,LEDBright
              add LEDGP,T1 wc
LEDGJmp       long %010111_0001_0011_000000000_000000000 + :LEDGOff
'        if_nc jmp #:LEDGOff
              or outa,LEDGMask
              jmp #:LEDGDone
:LEDGOff
              andn outa,LEDGMask
:LEDGDone              

              rdbyte T1,LEDBDutyPtr
              shl T1,LEDBright
              add LEDBP,T1 wc
LEDBJmp       long %010111_0001_0011_000000000_000000000 + :LEDBOff
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
              

LEDBright     long 16+LED_Brightness
LEDRMask      long (1 << LED_RPin)
LEDGMask      long (1 << LED_GPin)
LEDBMask      long (1 << LED_BPin)

SPKRMask      long (1 << SPKRPin)

RSTCTR        long  %01000_111 << 23 + BTTNPin << 9 + 0
RSTFRQ        long  1
RSTTIME       long  5*80_000_0000
RSTCLK        long  -1
RTCPTR        long RTCADDR
RTCLAST       res  1

T1            res  1
T2            res  1

LEDRDutyPtr   res  1
LEDGDutyPtr   res  1
LEDBDutyPtr   res  1

LEDRP         res  1     ' Red Phase
LEDGP         res  1     ' Green Phase
LEDBP         res  1     ' Blue Phase

              FIT
              
         