obj
  pause : "pause"
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  CARRIER_FREQ = 40_000
  T_DURATION = 600 ' microseconds


  ADDR_TV       = 1
  ADDR_VCR1     = 2
  ADDR_VCR2     = 3

  CMD_ENTER    = 11
  CMD_POWER    = 21
  CMD_CNL_UP   = 16
  CMD_CNL_DN   = 17
  CMD_VOL_UP   = 18
  CMD_VOL_DN   = 19
  CMD_SELFTEST   = 127
  CMD_VIDEO1   = 64
  CMD_VIDEO2   = 65
  CMD_VIDEO3   = 66
  CMD_VIDEO4   = 67
  
  CMD_PWR_OFF   = 47
  CMD_PWR_ON   = 46
var
  byte IRPin
pub start
  init(25)
  DIRA[IRPin]~~
  pause.delay_s(4)
  repeat
    sendCode(CMD_VOL_DN,ADDR_TV)
pub init(pin)
  IRPin := pin
  DIRA[IRPin]~
  CTRB := constant(%00100 << 26) | IRPin                
  FRQB := fraction(CARRIER_FREQ, CLKFREQ, 1)                               
{  SynthFreq(IRPin,CARRIER_FREQ)
PRI SynthFreq(Pin, Freq) | s, d, ctr, frq

  Freq := Freq #> 0 <# 128_000_000     'limit frequency range
  
  if Freq < 500_000                    'if 0 to 499_999 Hz,
    ctr := constant(%00100 << 26)      '..set NCO mode
    s := 1                             '..shift = 1
  else                                 'if 500_000 to 128_000_000 Hz,
    ctr := constant(%00010 << 26)      '..set PLL mode
    d := >|((Freq - 1) / 1_000_000)    'determine PLLDIV
    s := 4 - d                         'determine shift
    ctr |= d << 23                     'set PLLDIV
    
  frq := fraction(Freq, CLKFREQ, s)    'Compute FRQA/FRQB value
  ctr |= Pin                           'set PINA to complete CTRA/CTRB value

  CTRA := ctr                        'set CTRA
  FRQA := frq                        'set FRQA                   
  DIRA[Pin]~~                        'make pin output
}
PRI fraction(a, b, shift) : f

  if shift > 0                         'if shift, pre-shift a or b left
    a <<= shift                        'to maintain significant bits while 
  if shift < 0                         'insuring proper result
    b <<= -shift
 
  repeat 32                            'perform long division of a/b
    f <<= 1
    if a => b
      a -= b
      f++           
    a <<= 1
  
pub sendCodeRaw(data,bits)
  DIRA[IRPin]~
  pause.delay_ms(15)
  DIRA[IRPin]~~
  pause.delay_us(constant(T_DURATION*4))
  DIRA[IRPin]~
  repeat bits
    pause.delay_us(T_DURATION)
    DIRA[IRPin]~~
    pause.delay_us(T_DURATION)
    if(data & 1)
      pause.delay_us(T_DURATION)
    DIRA[IRPin]~
    data>>=1
  pause.delay_ms(15)

pub sendCode(command,address)
  if address < 64
    sendCodeRaw(command | (address<<7),12)
  elseif address < 255
    sendCodeRaw(command | (address<<7),15)
  else
    sendCodeRaw(command | (address<<7),20)
      