CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                                                      
  _stack = ($3000+(1024/4)+100) >> 2

  LampPin = 23

OBJ
 ' timer         : "timer"
  ir            : "ir_remote"
PUB start


  dira[LampPin] := 1

  outa[LampPin] := 0
  ir.init(6,1000)

  repeat while 1
    if ir.wait_for_signal == 5
      outa[LampPin] ^= 1 