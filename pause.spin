CON
  cntMin     = 400
VAR
  long ms
PUB Init
  ms    :=       clkfreq / 1_000
PUB Pause(dur) | clkCycles
  clkCycles := dur * ms-2300 #> cntMin               
  waitcnt( clkCycles + cnt )