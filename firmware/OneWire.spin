''=============================================================================
'' Copyright (C) 2006 Parallax, Inc. All rights reserved             
''
'' @file     OneWire
'' @target   Propeller
''
'' 1-wire interface routines.
'' This routine is intended for clock frequencies of 20 MHz and above. Timing
'' automatically adjusts to the system clock frequency, but most accurate timing
'' is achieved if the clock frequency is evenly divisible by 1,000,000.
''
'' @author   Cam Thompson, Micromega Corporation 
'' @version  V1.0 - July 15, 2006
'' @changes
''  - original version
''=============================================================================

CON
  setupCmd          = 1 << 16
  resetCmd          = 2 << 16
  writeCmd          = 3 << 16
  readCmd           = 4 << 16
  searchCmd         = 5 << 16
  crc8Cmd           = 6 << 16

  SEARCH_ROM        = $F0
  
VAR

  long  cog
  long  command, cmdReturn
  
PUB start(dataPin) : okay | pin, usec
  stop
  okay := cog := cognew(@getCommand, @command) + 1

  ' set pin to use for 1-wire interface and calculate usec delay 
  if okay
    pin := dataPin
    usec := (clkfreq + 999_999) / 1_000_000
    sendCmd(setupCmd + @pin)
    
PUB stop
  if cog
    cogstop(cog~ - 1)
  command~
         
PUB reset
  return sendCmd(resetCmd)

PUB writeAddress(p) | ah, al
  longmove(@ah, p, 2)
  writeBits(ah, 32)
  writeBits(al, 32)

PUB readAddress(p) | ah, al
  ah := readBits(32)
  al := readBits(32)
  longmove(p, @ah, 2)

PUB writeByte(b)
  writeBits(b, 8)

PUB writeBits(b, n)
  sendCmd(writeCmd + @b)
    
PUB readByte
  return readBits(8)

PUB readBits(n)
  return sendCmd(readCmd + @n)
          
PUB search(f, n, p)
  return sendCmd(searchCmd + @f)

PUB crc8(n, p)
  return sendCmd(crc8Cmd + @n)
          
PRI sendCmd(cmd)
  command := cmd
  repeat while command
  return cmdReturn  

DAT

'---------------------------
' Assembly language routines
'---------------------------
                        org

getCommand              rdlong  t1, par wz              ' wait for command
          if_z          jmp     #getCommand

                        mov     t2, t1                  ' get parameter pointer
                        
                        shr     t1, #16 wz              ' get command
                        max     t1, #(crc8Cmd>>16)      ' make sure valid range      
                        add     t1, #:cmdTable-1
                        jmp     t1                      ' jump to command

:cmdTable               jmp     #cmd_setup             ' command dispatch table 
                        jmp     #cmd_reset
                        jmp     #cmd_write
                        jmp     #cmd_read
                        jmp     #cmd_search
                        jmp     #cmd_crc8
                        
errorExit               neg     value, #1               ' set return to -1

endCommand              mov     t1, par                 ' return result
                        add     t1, #4
                        wrlong  value, t1
                        wrlong  Zero,par                ' clear command status
                        jmp     #getCommand             ' wait for next command

'------------------------------------------------------------------------------
' parameters: data pin, ticks per usec
' return:     none
'------------------------------------------------------------------------------

cmd_setup               rdlong  t1, t2                  ' get data pin
                        mov     dataMask, #1
                        shl     dataMask, t1
                        add     t2, #4                  ' get 1 usec delay period
                        rdlong  delay1usec, t2

                        mov     delay2usec, delay1usec  ' set delay values
                        add     delay2usec, delay1usec
                        mov     delay3usec, delay2usec
                        add     delay3usec, delay1usec
                        mov     delay4usec, delay3usec
                        add     delay4usec, delay1usec
                        sub     delay1usec, #13         ' adjust in-line delay values
                        sub     delay2usec, #13
                        sub     delay3usec, #13
                        jmp     #endCommand

'------------------------------------------------------------------------------
' parameters: none
' return:     0 if no presence, 1 is presence detected
'------------------------------------------------------------------------------

cmd_reset               call    #_reset                 ' send reset and exit
                        jmp     #endCommand

'------------------------------------------------------------------------------
' parameters: value, number of bits
' return:     none
'------------------------------------------------------------------------------

cmd_write               rdlong  value, t2               ' get the data byte
                        add     t2, #4                  
                        rdlong  bitCnt, t2 wz           ' get bit count    
          if_z          mov     bitCnt, #1              ' must be 1 to 32
                        max     bitCnt, #32
                        call    #_write                 ' write bits and exit
                        jmp     #endCommand
                        
'------------------------------------------------------------------------------
' parameters: number of bits 
' return:     value
'------------------------------------------------------------------------------

cmd_read                rdlong  bitCnt, t2              ' get bit count
          if_z          mov     bitCnt, #1              ' must be 1 to 32 
                        max     bitCnt, #32
                        call    #_read                  ' read bits and exit
                        jmp     #endCommand

'------------------------------------------------------------------------------
' parameters: family, maximum number of addresses, address pointer 
' return:     number of addresses
'------------------------------------------------------------------------------

cmd_search              rdlong  addrL, t2 wz            ' get family code            
                        mov     addrH, #0
          if_nz         mov     lastUnknown, #7         ' if non-zero, restrict search
          if_z          mov     lastUnknown, #0         ' if zero, search all
          
                        add     t2, #4                  ' get maximum number of addresses
                        rdlong  dataMax, t2
                        max     dataMax, #150 wz
          if_z          jmp     #:exit

                        add     t2, #4                  ' get data pointer
                        rdlong  dataPtr, t2
                        mov     dataCnt, #0             ' clear address count
                        
:nextAddr               call    #_reset                 ' reset the network                       
                        cmp     value, #0 wz            ' exit if no presence
          if_z          jmp     #:exit
                        mov     searchBit, #1           ' set initial search bit (1 to 64)
                        mov     unknown, #0             ' clear unknown marker
                        mov     addr, addrL             ' get address bits
                        mov     searchMask, #1          ' set search mask

                        mov     value, #SEARCH_ROM      ' send search ROM command
                        call    #_writeByte

:nextBit                mov     bitCnt, #2              ' read two bits
                        call    #_read

                        cmp     value,#%00 wz           ' 00 - device conflict
          if_nz         jmp     #:check10
                        cmp     searchBit, lastUnknown wz,wc
          if_z          or      addr, searchMask
          if_z          jmp     #:sendBit
          if_nc         andn    addr, searchMask
          if_nc         mov     unknown, searchBit
          if_nc         jmp     #:sendBit
                        test    addr, searchMask wz
          if_z          mov     unknown, searchBit
                        jmp     #:sendBit
                                 
:check10                cmp     value, #%10 wz          ' 10 - all devices have 0 bit
          if_z          andn    addr, searchMask
          if_z          jmp     #:sendBit
                        
:check01                cmp     value, #%01 wz          ' 01 - all devices have 1 bit
          if_z          or      addr, searchMask
          if_z          jmp     #:sendBit
              
                        jmp     #:exit                  ' 11 - no devices responding 

:sendBit                test    addr, searchMask wc     ' send reply bit
                        muxc    value, #1
                        mov     bitCnt, #1
                        call    #_write

                        add     searchBit, #1           ' increment search count
                        rol     searchMask, #1          ' adjust mask
                        cmp     searchBit, #33 wz       ' check for upper 32 bits
          if_z          mov     addrL, addr
          if_z          mov     addr, addrH
                        cmp     searchBit, #65 wz       ' repeat for all 64 bits
          if_nz         jmp     #:nextBit
                    
                        wrLong  addrL, dataPtr          ' store address
                        add     dataPtr, #4
                        mov     addrH, addr
                        wrLong  addrH, dataPtr
                        add     dataPtr, #4

                        add     dataCnt, #1             ' increment address count
                        cmp     dataCnt, dataMax wc
                        mov     lastUnknown, unknown wz ' update last unknown bit
          if_nz_and_c   jmp     #:nextAddr              ' repeat if more addresses
                        
:exit                   mov     value, dataCnt          ' return number of addresses found
                        jmp     #endCommand

'------------------------------------------------------------------------------
' parameters: byte count, address pointer
' return:     crc8
'------------------------------------------------------------------------------

cmd_crc8                rdlong  dataCnt, t2             ' get number of bytes
                        add     t2, #4                  ' get data pointer
                        rdlong  dataPtr, t2

                        mov     value, #0               ' clear CRC

:nextByte               rdbyte  addr, dataPtr           ' get next byte
                        add     dataPtr, #1
                        mov     bitCnt, #8

:nextBit                mov     t1, addr                ' x^8 + x^5 + x^4 + 1 
                        shr     addr, #1
                        xor     t1, value
                        shr     value, #1
                        shr     t1, #1 wc
          if_c          xor     value, #$8C
                        djnz    bitCnt, #:nextBit  
                        djnz    dataCnt, #:nextByte
                        jmp     #endCommand
                        
'------------------------------------------------------------------------------
' input:  none
' output: value         0 if no presence, 1 is presence detected
'------------------------------------------------------------------------------

_reset                  andn    outa, dataMask          ' set data low
                        or      dira, dataMask
         
                        mov     t1, #500                ' delay 500 usec
                        call    #_delay

                        andn    dira, dataMask          ' set data to high Z

                        mov     t1, #72                 ' delay 72 usec
                        call    #_delay

                        test    dataMask, ina wc        ' check for presence
          if_c          mov     value, #0
          if_nc         mov     value, #1

                        mov     t1, #428                ' delay 428 usec
                        call    #_delay
_reset_ret              ret

'------------------------------------------------------------------------------
' input:  value         data bits
'         bitCount      number of bits
' output: none
'------------------------------------------------------------------------------

_writeByte              mov     bitCnt, #8              ' write an 8-bit byte

_write                  andn    outa, dataMask          ' set data low for 8 usec
                        or      dira, dataMask
                        mov     t1, #8
                        call    #_delay

                        ror     value, #1 wc            ' check next bit
          if_c          andn    dira, dataMask          ' if 1, set data to high Z

                        mov     t1, #64                 ' hold for 64 usec
                        call    #_delay
                        
                        andn    dira, dataMask          ' set data to high Z for 8 usec
                        mov     t1, #8
                        call    #_delay

                        djnz    bitCnt, #_write         ' repeat for all bits
_writeByte_ret
_write_ret              ret

'------------------------------------------------------------------------------
' input:  bitCount      number of bits
' output: value         data bits
'------------------------------------------------------------------------------


_readByte               mov     bitCnt, #8              ' read an 8-bit byte

_read                   mov     shiftCnt, #32           ' get shift count
                        sub     shiftCnt, bitCnt

:read2                  andn    outa, dataMask          ' set data low for 4 usec
                        or      dira, dataMask
                        mov     t1, #4
                        call    #_delay

                        andn    dira, dataMask          ' set data to high Z
                        mov     t1, #4                  ' delay 4 usec
                        call    #_delay

                        test    dataMask,ina wc         ' read next bit
                        rcr     value, #1

                        mov     t1, #72                 ' delay for 72 usec
                        call    #_delay
 
                        djnz    bitCnt, #:read2         ' repeat for all bits

                        shr     value, shiftCnt         ' right justify
_readByte_ret
_read_ret               ret
                      
'------------------------------------------------------------------------------
' input:  t1            number of usec to delay (must be multiple of 4)
' output: none
'------------------------------------------------------------------------------

_delay                  shr     t1, #2 wz               ' divide delay count by 4
          if_z          mov     t1, #1                  ' ensure at least one delay
                        mov     t2, delay4usec          ' get initial delay
                        add     t2, cnt
                        sub     t2, #41                 ' adjust for call overhead

:wait                   waitcnt t2, delay4usec          ' wait for 4 usec
                        djnz    t1, #:wait              ' loop while delay count > 0
_delay_ret              ret
      
'-------------------- constant values -----------------------------------------

Zero                    long    0                       ' constants

'-------------------- local variables -----------------------------------------

t1                      res     1                       ' temporary values
t2                      res     1
bitCnt                  res     1                       ' bit counter
shiftCnt                res     1                       ' shift counter
dataMask                res     1                       ' data pin mask
value                   res     1                       ' data value / return value
dataPtr                 res     1                       ' data pointer
dataCnt                 res     1                       ' data count
dataMax                 res     1                       ' maximum data count

searchBit               res     1                       ' current search bit
searchMask              res     1                       ' search mask
unknown                 res     1                       ' current unknown bit
lastUnknown             res     1                       ' last unknown search bit
addr                    res     1                       ' current address
addrL                   res     1                       ' lower 32 bits of address
addrH                   res     1                       ' upper 32 bits of address

delay1usec              res     1                       ' 1 usec delay
delay2usec              res     1                       ' 2 usec delay
delay3usec              res     1                       ' 3 usec delay
delay4usec              res     1                       ' 4 usec delay