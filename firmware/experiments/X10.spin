{{
  X10 Powerline Interface, for PSC05
  Version 1.0
  Written by Robert Quattlebaum <darco@deepdarc.com>

  See http://www.x10pro.com/pro/pdf/technote.pdf for more info.
  (Requires the circuit from page 10.)

  THIS OBJECT IS RELEASED TO THE PUBLIC DOMAIN. USE AS YOU SEE FIT.

  In jusisdictions/situations where a license is required, I hereby
  release this object under the terms of the MIT license, as
  documented here: http://www.opensource.org/licenses/mit-license.php
}}
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  HOUSE_A       = %0110
  HOUSE_B       = %1110
  HOUSE_C       = %0010
  HOUSE_D       = %1001
  HOUSE_E       = %0001
  HOUSE_F       = %1001
  HOUSE_G       = %0101
  HOUSE_H       = %1101
  HOUSE_I       = %0111
  HOUSE_J       = %1111
  HOUSE_K       = %0011
  HOUSE_L       = %1011
  HOUSE_M       = %0000
  HOUSE_N       = %1000
  HOUSE_O       = %0100
  HOUSE_P       = %1100

  UNIT_01       = %01100
  UNIT_02       = %11100
  UNIT_03       = %00100
  UNIT_04       = %10100
  UNIT_05       = %00010
  UNIT_06       = %10010
  UNIT_07       = %01010

  UNIT_08       = %11010
  UNIT_09       = %01110
  UNIT_10       = %11110
  UNIT_11       = %00110
  UNIT_12       = %10110
  UNIT_13       = %00000
  UNIT_14       = %10000
  UNIT_15       = %01000
  UNIT_16       = %11000
  
  CMD_ALL_OFF   = %00001
  CMD_LIGHTS_ON = %00011
  CMD_ON        = %00101
  CMD_OFF       = %00111
  CMD_DIM       = %01001
  CMD_BRIGHT    = %01011
  CMD_LIGHTS_OFF = %01101
  CMD_HAIL_REQ  = %10001
  CMD_HAIL_ACK  = %10011
  CMD_STATUS_ON = %11011
  CMD_STATUS_OFF = %11101
  CMD_STATUS_REQ = %11111
  CMD_EXT        = %01111

  EXT_CMD_PRESET = %00110000

OBJ
  pause          : "pause"
  
VAR
  byte zcPin,inPin,outPin
  
PUB start(zcPin_,inPin_,outPin_)
  zcPin := zcPin_
  inPin := inPin_
  outPin := outPin_
  dira[zcPin]~
  dira[inPin]~
  dira[outPin]~

PUB send_ext_to_unit(house,unit,cmd,data)
  repeat 2
    send_raw(house,CMD_EXT)
    send_bits(unit,5)
    send_bits(data,8)
    send_bits(cmd,8)
  pushbit(0)
  pushbit(0)
  pushbit(0)

PUB send_to_unit(house,unit,code)
  send(house,unit)
  send(house,code)

PUB dim(house,amt)
  repeat amt+1
    send_raw(house,CMD_DIM)
  pushbit(0)
  pushbit(0)
  pushbit(0)

PUB bright(house,amt)
  repeat amt+1
    send_raw(house,CMD_BRIGHT)
  pushbit(0)
  pushbit(0)
  pushbit(0)

PUB send(house,code)
  send_raw(house,code)
  send_raw(house,code)
  pushbit(0)
  pushbit(0)
  pushbit(0)

PRI pushbit(val) : i
  outa[outPin] := val&1
  if ina[zcPin]
    waitpeq(0,|<zcPin,0)
  else
    waitpne(0,|<zcPin,0)
  dira[outPin]~~
  pause.delay_ms(1)
  dira[outPin]~

PUB send_raw(house,code)
  pushbit(1)
  pushbit(1)
  pushbit(1)
  pushbit(0)
  send_bits(house,4)
  send_bits(code,5)

PUB send_bits(data,bits)
  bits--
  repeat bits+1
    pushbit(data>>bits)
    pushbit(!(data>>bits))
    data<<=1
  