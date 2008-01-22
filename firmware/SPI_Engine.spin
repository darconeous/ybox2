{
                                ********************************************
                                                 SPI Engine             V1.1    
                                ********************************************
                                      coded by Beau Schwabe (Parallax)
                                ********************************************
Revision History:
         V1.0   - original program
         
         V1.1   - fixed problem with SHIFTOUT MSBFIRST option
                - fixed argument allocation in the SPI Engines main loop
}
CON
  #1,_SHIFTOUT,_SHIFTIN
  #0,mMSBPRE,mLSBPRE,mMSBPOST,mLSBPOST                                           'Used for SHIFTIN routines
  #4,mLSBFIRST,mMSBFIRST                                                        'Used for SHIFTOUT routines
VAR
    long     cog, command, Flag
PUB SHIFTOUT(Dpin, Cpin, Mode, Bits, Value)             'Once called from Spin, SHIFTOUT remains running in its own COG.
    if Flag == 0                                        'If SHIFTOUT is called with 'Bits' set to Zero, then the COG will shut
       start                                            'down.  Another way to shut the COG down is to call 'stop' from Spin.
    setcommand(_SHIFTOUT, @Dpin)
PUB SHIFTIN(Dpin, Cpin, Mode, Bits)|Value               'Once called from Spin, SHIFTIN remains running in its own COG.
    if Flag == 0                                        'If SHIFTIN is called with 'Bits' set to Zero, then the COG will shut
       start                                            'down.  Another way to shut the COG down is to call 'stop' from Spin.
    setcommand(_SHIFTIN, @Dpin)
    result := Value
'------------------------------------------------------------------------------------------------------------------------------
PUB start : okay
'' Start SPI Engine - starts a cog
'' returns false if no cog available
    stop
    Flag := 1
    okay := cog := cognew(@loop, @command) + 1
PUB stop
'' Stop SPI Engine - frees a cog
    Flag := 0
    if cog
       cogstop(cog~ - 1)
    command~
PRI setcommand(cmd, argptr)
    command := cmd << 16 + argptr                       'write command and pointer
    repeat while command                                'wait for command to be cleared, signifying receipt
'################################################################################################################
DAT           org
'  
' SPI Engine - main loop
'
loop          rdlong  t1,par          wz                'wait for command
        if_z  jmp     #loop
              movd    :arg,#arg0                        'get 5 arguments ; arg0 to arg4
              mov     t2,t1                             '    │
              mov     t3,#5                             '───┘ 
:arg          rdlong  arg0,t2
              add     :arg,d0
              add     t2,#4
              djnz    t3,#:arg
              mov     address,t1                        'preserve address location for passing
                                                        'variables back to Spin language.
              wrlong  zero,par                          'zero command to signify command received
              ror     t1,#16+2                          'lookup command address
              add     t1,#jumps
              movs    :table,t1
              rol     t1,#2
              shl     t1,#3
:table        mov     t2,0
              shr     t2,t1
              and     t2,#$FF
              jmp     t2                                'jump to command
jumps         byte    0                                 '0
              byte    SHIFTOUT_                         '1
              byte    SHIFTIN_                          '2
              byte    NotUsed_                          '3
NotUsed_      jmp     #loop
'################################################################################################################
SHIFTOUT_                                               'SHIFTOUT Entry
              mov     t4,             arg3      wz      '     Load number of data bits
    if_z      jmp     #Done                             '     '0' number of Bits = Done
              mov     t1,             #1        wz      '     Configure DataPin
              shl     t1,             arg0
              muxz    outa,           t1                '          PreSet DataPin LOW
              muxnz   dira,           t1                '          Set DataPin to an OUTPUT
              mov     t2,             #1        wz      '     Configure ClockPin
              shl     t2,             arg1
              muxz    outa,           t2                '          PreSet ClockPin LOW
              muxnz   dira,           t2                '          Set ClockPin to an OUTPUT
              sub     LSBFIRST,       arg2    wz,nr     '     Detect LSBFIRST mode for SHIFTOUT
    if_z      jmp     #LSBFIRST_
              sub     MSBFIRST,       arg2    wz,nr     '     Detect MSBFIRST mode for SHIFTOUT
    if_z      jmp     #MSBFIRST_             
              jmp     #loop                             '     Go wait for next command
'------------------------------------------------------------------------------------------------------------------------------
SHIFTIN_                                                'SHIFTIN Entry
              mov     t4,             arg3      wz      '     Load number of data bits
    if_z      jmp     #Done                             '     '0' number of Bits = Done
              mov     t1,             #1        wz      '     Configure DataPin
              shl     t1,             arg0
              muxz    dira,           t1                '          Set DataPin to an INPUT
              mov     t2,             #1        wz      '     Configure ClockPin
              shl     t2,             arg1
              muxz    outa,           t2                '          PreSet ClockPin LOW
              muxnz   dira,           t2                '          Set ClockPin to an OUTPUT
              sub     MSBPRE,         arg2    wz,nr     '     Detect MSBPRE mode for SHIFTIN
    if_z      jmp     #MSBPRE_
              sub     LSBPRE,         arg2    wz,nr     '     Detect LSBPRE mode for SHIFTIN
    if_z      jmp     #LSBPRE_
              sub     MSBPOST,        arg2    wz,nr     '     Detect MSBPOST mode for SHIFTIN
    if_z      jmp     #MSBPOST_
              sub     LSBPOST,        arg2    wz,nr     '     Detect LSBPOST mode for SHIFTIN
    if_z      jmp     #LSBPOST_
              jmp     #loop                             '     Go wait for next command
'------------------------------------------------------------------------------------------------------------------------------              
MSBPRE_                                                 '     Receive Data MSBPRE
MSBPRE_Sin    test    t1,             ina     wc        '          Read Data Bit into 'C' flag
              rcl     t3,             #1                '          rotate "C" flag into return value
              call    #Clock                            '          Send clock pulse
              djnz    t4,             #MSBPRE_Sin       '          Decrement t4 ; jump if not Zero
              jmp     #Update_SHIFTIN                   '     Pass received data to SHIFTIN receive variable
'------------------------------------------------------------------------------------------------------------------------------              
LSBPRE_                                                 '     Receive Data LSBPRE
LSBPRE_Sin    test    t1,             ina       wc      '          Read Data Bit into 'C' flag
              rcr     t3,             #1                '          rotate "C" flag into return value
              call    #Clock                            '          Send clock pulse
              djnz    t4,             #LSBPRE_Sin       '     Decrement t4 ; jump if not Zero
              mov     t4,             #32               '     For LSB shift data right 32 - #Bits when done
              sub     t4,             arg3
              shr     t3,             t4
              jmp     #Update_SHIFTIN                   '     Pass received data to SHIFTIN receive variable
'------------------------------------------------------------------------------------------------------------------------------
MSBPOST_                                                '     Receive Data MSBPOST
MSBPOST_Sin   call    #Clock                            '          Send clock pulse
              test    t1,             ina     wc        '          Read Data Bit into 'C' flag
              rcl     t3,             #1                '          rotate "C" flag into return value
              djnz    t4,             #MSBPOST_Sin      '          Decrement t4 ; jump if not Zero
              jmp     #Update_SHIFTIN                   '     Pass received data to SHIFTIN receive variable
'------------------------------------------------------------------------------------------------------------------------------
LSBPOST_                                                '     Receive Data LSBPOST
LSBPOST_Sin   call    #Clock                            '          Send clock pulse
              test    t1,             ina       wc      '          Read Data Bit into 'C' flag
              rcr     t3,             #1                '          rotate "C" flag into return value
              djnz    t4,             #LSBPOST_Sin      '          Decrement t4 ; jump if not Zero
              mov     t4,             #32               '     For LSB shift data right 32 - #Bits when done
              sub     t4,             arg3
              shr     t3,             t4
              jmp     #Update_SHIFTIN                   '     Pass received data to SHIFTIN receive variable
'------------------------------------------------------------------------------------------------------------------------------
LSBFIRST_                                               '     Send Data LSBFIRST
              mov     t3,             arg4              '          Load t3 with DataValue
LSB_Sout      test    t3,             #1      wc       '          Test LSB of DataValue
              muxc    outa,           t1                '          Set DataBit HIGH or LOW
              shr     t3,             #1                '          Prepare for next DataBit
              call    #Clock                            '          Send clock pulse
              djnz    t4,             #LSB_Sout         '          Decrement t4 ; jump if not Zero
              mov     t3,             #0      wz        '          Force DataBit LOW
              muxnz   outa,           t1
              jmp     #loop                             '     Go wait for next command
'------------------------------------------------------------------------------------------------------------------------------
MSBFIRST_                                               '     Send Data MSBFIRST
              mov     t3,             arg4              '          Load t3 with DataValue
              mov     t5,             #%1               '          Create MSB mask     ;     load t5 with "1"
              shl     t5,             arg3              '          Shift "1" N number of bits to the left.
              shr     t5,             #1                '          Shifting the number of bits left actually puts
                                                        '          us one more place to the left than we want. To
                                                        '          compensate we'll shift one position right.              
MSB_Sout      test    t3,             t5      wc        '          Test MSB of DataValue
              muxc    outa,           t1                '          Set DataBit HIGH or LOW
              shr     t5,             #1                '          Prepare for next DataBit
              call    #Clock                            '          Send clock pulse
              djnz    t4,             #MSB_Sout         '          Decrement t4 ; jump if not Zero
              mov     t3,             #0      wz        '          Force DataBit LOW
              muxnz   outa,           t1
              
              jmp     #loop                             '     Go wait for next command
'------------------------------------------------------------------------------------------------------------------------------
Update_SHIFTIN
              mov     t1,             address           '     Write data back to Arg4
              add     t1,             #16               '          Arg0 = #0 ; Arg1 = #4 ; Arg2 = #8 ; Arg3 = #12 ; Arg4 = #16
              wrlong  t3,             t1
              jmp     #loop                             '     Go wait for next command
'------------------------------------------------------------------------------------------------------------------------------
Clock
              mov     t2,             #0      wz,nr     '     Clock Pin
              muxz    outa,           t2                '          Set ClockPin HIGH
              muxnz   outa,           t2                '          Set ClockPin LOW
Clock_ret     ret                                       '          return
'------------------------------------------------------------------------------------------------------------------------------
Done                                                    '     Shut COG down
              mov     t2,             #0                '          Preset temp variable to Zero
              mov     t1,             par               '          Read the address of the first perimeter
              add     t1,             #4                '          Add offset for the second perimeter ; The 'Flag' variable
              wrlong  t2,             t1                '          Reset the 'Flag' variable to Zero
              CogID   t1                                '          Read CogID
              COGSTOP t1                                '          Stop this Cog!
'------------------------------------------------------------------------------------------------------------------------------
{
########################### Defined data ###########################
}
zero                    long    0                       'constants
d0                      long    $200

MSBPRE                  long    $0                      '          Applies to SHIFTIN
LSBPRE                  long    $1                      '          Applies to SHIFTIN
MSBPOST                 long    $2                      '          Applies to SHIFTIN
LSBPOST                 long    $3                      '          Applies to SHIFTIN
LSBFIRST                long    $4                      '          Applies to SHIFTOUT
MSBFIRST                long    $5                      '          Applies to SHIFTOUT
{
########################### Undefined data ###########################
}
                                                        'temp variables
t1                      res     1                       '     Used for DataPin mask     and     COG shutdown 
t2                      res     1                       '     Used for CLockPin mask    and     COG shutdown
t3                      res     1                       '     Used to hold DataValue SHIFTIN/SHIFTOUT
t4                      res     1                       '     Used to hold # of Bits
t5                      res     1                       '     Used for temporary data mask
address                 res     1                       '     Used to hold return address of first Argument passed

arg0                    res     1                       'arguments passed to/from high-level Spin
arg1                    res     1
arg2                    res     1
arg3                    res     1
arg4                    res     1