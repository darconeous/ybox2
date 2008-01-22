VAR
  long cog                                 
  long stack[6] 'Stack space for new cog  
  byte timer_overflow
  byte timer_paused
  long dur
 
PUB Start(timer_millis):okay

  stop
  timer_overflow := FALSE
  dur := timer_millis       
  
  okay := cog := cognew(Run, @stack) + 1 

PUB Stop      
  if cog
    cogstop(cog~ - 1)
  'term.stop
  
PUB Check:b
  if timer_overflow
    timer_overflow := FALSE
    b := TRUE
  else
    b := FALSE
     
PUB Reset
   timer_paused := FALSE 
PRI Run | clkCycles
          
  clkCycles := (clkfreq/1000)*dur
  waitcnt(clkCycles + cnt)
  timer_overflow := TRUE
  timer_paused := TRUE 
  repeat
    repeat while timer_paused
    waitcnt( clkCycles + cnt )
    timer_overflow := TRUE
    timer_paused := TRUE