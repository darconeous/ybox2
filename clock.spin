{{
***************************
* Clock v1.1              *
* Author: Jeff Martin     *
* (C) 2006 Parallax, Inc. *
***************************

Provides clock timing functions to:
  • Set clock mode/frequency at run-time using the same clock setting constants as with _CLKMODE,
  • Pause execution in units of microseconds, milliseconds, or seconds, 
  • Synchronize code to the start of time-windows in units of microseconds, milliseconds, or seconds.

See "Theory of Operation" below for more information.

{{--------------------------REVISION HISTORY--------------------------
 v1.1 - Updated 11/27/2006 to fix clock mode value when mode is XINPUT

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
}}

CON
  WMin  =       381                                                                                     'WAITCNT-expression-overhead Minimum

VAR
  long  XINFreq                                                                                         'Propeller XIN frequency
  long  SyncPoint                                                                                       'Next sync point for WaitSync

PUB Init(XINFrequency)
{{Call this before first call to SetClock.
  PARAMETERS: XINFrequency = Frequency (in Hz) that external crystal/clock is driving into XIN pin.
                             Use 0 if no external clock source connected to Propeller.
}}
   XINFreq := XINFrequency
   
  
PUB SetClock(Mode): NewFreq | PLLx, XTALx, RCx
{{Set System Clock to Mode.
Exits without modifying System Clock if Mode is invalid.
  PARAMETERS: Mode = a combination of RCSLOW, RCFAST, XINPUT, XTALx and PLLx clock setting constants.
  RETURNS:    New clock frequency.
}}                                                                                                      
  if Valid(Mode)                                                                                           'If Mode is valid                                                                     'The following is the enumerated   
    RCx   := Mode & $3                                                                                     '  Get RCSLOW, RCFAST setting                                                         'clock setting constants that are  
    XTALx := Mode >> 2 & $F                                                                                '  Get XINPUT, XTAL1, XTAL2, XTAL3 setting                                            'used for the Mode parameter.      
    PLLx  := Mode >> 6 & $1F                                                                               '  Get PLL1X, PLL2X, PLL4X, PLL8X, PLL16X setting                                     ' ┌──────────┬───────┬──────┐      
                                                                                                                                                                                                 ' │ Clock    │       │ Mode │      
           '┌───────────────────────────────── New CLK Register Value ─────────────────────────────────┐                                                                                         ' │ Setting  │ Value │ Bit  │      
           '┌────── PLLENA & OSCENA (6&5) ─────┐   ┌── OSCMx (4:3) ───┐   ┌─────── CLKSELx (2:0) ───────┐                                                                                        ' │ Constant │       │      │      
    Mode := $60 & (PLLx > 0) | $20 & (XTALx > 0) | >| (XTALx >> 1) << 3 | $12 >> (3 - RCx) & $3 + >| PLLx  '  Calculate new clock mode (CLK Register Value)                                      ' ├──────────┼───────┼──────┤      
           '└── any PLLx? ─┘   └ XTALx/XINPUT? ┘   └───── XTALx ──────┘   └── RCx and XINPUT ─┘   └─PLLx┘                                                                                        ' │  PLL16x  │ 1024  │  10  │      
                                                                                                                                                                                                 ' │  PLL8x   │  512  │   9  │      
    NewFreq := XINFreq*(PLLx#>||(RCx==0)) + 12_000_000*RCx&$1 + 20_000*RCx>>1                              '  Calculate new system clock frequency                                               ' │  PLL4x   │  256  │   8  │      
                                                                                                                                                                                                 ' │  PLL2x   │  128  │   7  │      
    if not ((clkmode < $20) and (Mode > $20))                                                              '  If not switching from internal to external plus oscillator and PLL circuits        ' │  PLL1x   │   64  │   6  │      
      clkset(Mode, NewFreq)                                                                                '    Switch to new clock mode immediately (and set new frequency)                     ' │  XTAL3   │   32  │   5  │      
    else                                                                                                   '  Else                                                                               ' │  XTAL2   │   16  │   4  │      
      clkset(Mode & $78 | clkmode & $07, clkfreq)                                                          '    Rev up the oscillator and PLL circuits first                                     ' │  XTAL1   │    8  │   3  │      
      waitcnt(clkfreq / 100 + cnt)                                                                         '    Wait 10 ms for them to stabilize                                                 ' │  XINPUT  │    4  │   2  │      
      clkset(Mode, NewFreq)                                                                                '    Then switch to external clock (and set new frequency)                            ' │  RCSLOW  │    2  │   1  │      
                                                                                                                                                                                                 ' │  RCFAST  │    1  │   0  │      
  NewFreq := clkfreq                                                                                       'Return clock frequency                                                               ' └──────────┴───────┴──────┘      
                                                                                                                                                                                         
  
PUB PauseUSec(Duration) 
{{Pause execution in microseconds.
  PARAMETERS: Duration = number of microseconds to delay.
}}
  waitcnt(((clkfreq / 1_000_000 * Duration - 3928) #> WMin) + cnt)                                 
  

PUB PauseMSec(Duration)
{{Pause execution in milliseconds.
  PARAMETERS: Duration = number of milliseconds to delay.
}}
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> WMin) + cnt)                                     
  

PUB PauseSec(Duration)
{{Pause execution in seconds.
  PARAMETERS: Duration = number of seconds to delay.
}}
  waitcnt(((clkfreq * Duration - 3016) #> WMin) + cnt)                                             
                                                                                                 
                                                                                                 
PUB MarkSync                                                                                     
{{Mark reference time for synchronized-delay time windows.                                       
Use one of the WaitSync methods to sync to start of next time window.                            
}}                                                                                               
  SyncPoint := cnt                                                                               
                                                                                                 
                                                                                                 
PUB WaitSyncUSec(Width)                                                                          
{{Sync to start of next microsecond-based time window.                                           
Must call MarkSync before calling WaitSyncUSec the first time.                                   
  PARAMETERS: Width = size of time window in microseconds.                                       
}}                                                                                               
  waitcnt(SyncPoint += (clkfreq / 1_000_000 * Width) #> WMin)                                    
                                                                                                 
                                                                                                 
PUB WaitSyncMSec(Width)                                                                          
{{Sync to start of next millisecond-based time window.                                           
Must call MarkSync before calling WaitSyncMSec the first time.                                   
  PARAMETERS: Width = size of time window in milliseconds.                                       
}}                                                                                               
  waitcnt(SyncPoint += (clkfreq / 1_000 * Width) #> WMin)                                        
                                                                                                 
                                                                                                 
PUB WaitSyncSec(Width)                                                                           
{{Sync to start of next second-based time window.                                                
Must call MarkSync before calling WaitSyncSec the first time.                                    
  PARAMETERS: Width = size of time window in seconds.                                            
}}                                                                                               
  waitcnt(SyncPoint += (clkfreq * Width) #> WMin)                                                
  

PRI Valid(Mode): YesNo
{Returns True if Mode (combined with XINFreq) is a valid clock mode, False otherwise.}

  YesNo := OneBit(Mode & $03F) and OneBit(Mode & $7C3) and not ((Mode & $7C0) and not (Mode & $3C)) and not ((XINFreq == 0) and (Mode & $3C <> 0))
  

PRI OneBit(Bits): YesNo
{Returns True if Bits has less than 2 bits set, False otherwise.
This is a "mutually-exclusive" test; if any bit is set, all other bits must be clear or the test fails.}

  YesNo := Bits == |< >| Bits >> 1
  

{{


──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
                                                     THEORY OF OPERATION
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Use this object to control the system clock and cog execution.
                                                                           ┌─────────────────┬──────────────┐     
                                                                           │   Valid Clock   │ CLK Register │
                                                                           │      Modes      │    Value     │
                                                                           ├─────────────────┼──────────────┤
                                                                           │ RCFAST          │ 0_0_0_00_000 │
TO SET THE SYSTEM CLOCK AT RUN-TIME:                                       ├─────────────────┼──────────────┤
                                                                           │ RCSLOW          │ 0_0_0_00_001 │                    
                                                                           ├─────────────────┼──────────────┤                    
    STEP 1: Call Init with the frequency (in Hz) of the external           │ XINPUT          │ 0_0_1_00_010 │
            crystal/clock on the XIN pin (if any). For example,            ├─────────────────┼──────────────┤
            use Init(5_000_000) to specify an XIN pin frequency            │ XTAL1           │ 0_0_1_01_010 │
            of 5 MHz.                                                      │ XTAL2           │ 0_0_1_10_010 │                
                                                                           │ XTAL3           │ 0_0_1_11_010 │                    
    STEP 2: Call SetClock with the new clock mode to switch to;            ├─────────────────┼──────────────┤
            expressed in clock setting constants similar to how the        │ XINPUT + PLL1X  │ 0_1_1_00_011 │
            _CLKMODE constant is defined for the application's initial     │ XINPUT + PLL2X  │ 0_1_1_00_100 │
            clock setting.  For example, use SetClock(XTAL1 + PLL4X)       │ XINPUT + PLL4X  │ 0_1_1_00_101 │
            to switch the System Clock to an external low-speed crystal    │ XINPUT + PLL8X  │ 0_1_1_00_110 │
            source and wind it up by 4 times.                              │ XINPUT + PLL16X │ 0_1_1_00_111 │                               
                                                                           ├─────────────────┼──────────────┤                    
    The table on the right shows all valid clock setting constants as      │ XTAL1 + PLL1X   │ 0_1_1_01_011 │
    well as the CLK Register bit patterns they correspond to.              │ XTAL1 + PLL2X   │ 0_1_1_01_100 │                                                
                                                                           │ XTAL1 + PLL4X   │ 0_1_1_01_101 │                    
    NOTE: The SetClock method automatically validates the clock mode       │ XTAL1 + PLL8X   │ 0_1_1_01_110 │
    settings, calculates and updates the System Clock Frequency value      │ XTAL1 + PLL16X  │ 0_1_1_01_111 │
    (CLKFREQ) and performs the appropriate stabilization procedure, as     ├─────────────────┼──────────────┤
    needed, to ensure a stable clock when switching between internal       │ XTAL2 + PLL1X   │ 0_1_1_10_011 │
    and external clock sources.  In addition to the required 10 ms         │ XTAL2 + PLL2X   │ 0_1_1_10_100 │
    stabilization period for internal-to-external clock source switches,   │ XTAL2 + PLL4X   │ 0_1_1_10_101 │    
    an additional delay of approximately 75 µs occurs while the            │ XTAL2 + PLL8X   │ 0_1_1_10_110 │
    hardware switches the source.                                          │ XTAL2 + PLL16X  │ 0_1_1_10_111 │
                                                                           ├─────────────────┼──────────────┤
                                                                           │ XTAL3 + PLL1X   │ 0_1_1_11_011 │
                                                                           │ XTAL3 + PLL2X   │ 0_1_1_11_100 │
                                                                           │ XTAL3 + PLL4X   │ 0_1_1_11_101 │
                                                                           │ XTAL3 + PLL8X   │ 0_1_1_11_110 │
                                                                           │ XTAL3 + PLL16X  │ 0_1_1_11_111 │
                                                                           └─────────────────┴──────────────┘
TO PAUSE EXECUTION BRIEFLY:                                               
                                                                          
          
    STEP 1: Call PauseUSec, PauseMSec, or PauseSec to pause for durations in units of microseconds, milliseconds,
            or seconds, respectively.

    NOTE: The Pause methods automatically do the following:
          • Adjusts for System Clock changes so that their duration is consistent as long as the System Clock
            frequency does not change during a pause operation itself.
          • Adjusts the specified duration down to compensate for the Spin Interpreter overhead of calling the
            method, performing the delay, and returning from the method.  This is so the effect of a Pause statement
            is a delay that is as close to the desired delay as possible, rather than being the desired delay plus
            the call/return delay.  The actual delay will vary slightly depending on the expression used for the
            duration.
          • Limits the minimum duration to a "Spin Interpreter" safe value that will not cause apparent "lock ups"
            associated with waiting for a System Counter value that has already passed.

    Keep in mind that System Clock frequency can greatly affect the shortest durations that are possible.  For example,
    in Spin code, while running at 80 MHz, the shortest duration for PauseUSec is about 54 (54 microseconds), but it
    can reliably delay for 55 µs, 56 µs, 57 µs, etc. beyond that lower limit.  When running at 20 KHz, the shortest
    that PauseMSec can delay is about 216 (216 milliseconds), but it can reliably delay for 217 ms, 218 ms, etc. 
    
          





TO SYNCHRONIZE A COMMAND/ROUTINE TO A WINDOW OF TIME (Synchronized Delays):                                               
                                                                          
          
    STEP 1: Call MarkSync to mark the reference point in time.

    STEP 2: Call WaitSyncUSec, WaitSyncMSec, or WaitSyncSec immediately before the command/routine you wish to 
            synchronize, to wait for the start of the next window of time (measured in units of microseconds,
            milliseconds, or seconds, respectively).
         
    NOTE: The WaitSync methods automatically do the following:
          • Adjusts for System Clock changes so that their time-window width is consistent as long as the System
            Clock frequency does not change during a wait operation itself.
          • Limits the minimum width to a "Spin Interpreter" safe value that will not cause apparent "lock ups"
            associated with waiting for a System Counter value that has already passed.
          
    In loops, the MarkSync/WaitSync methods (Synchronized Delays) have an advantage over the Pause methods in
    that they automatically compensate for the loop's overhead so that the command following the WaitSync
    executes at the exact same interval each time, even if the loop itself has multiple decision paths that
    each take different amounts of time to execute.

    For example, the following code uses PauseUSec in a loop that toggles a pin (assume T is this Clock object
    and we are using an accurate, external clock source):

          dira[16]~~
          repeat
            T.PauseUSec(100)
            !outa[16]          
          
    This produces a signal on P16 that looks similar to the following timing diagram.

          P16 ─       
                                                      ... 
                0   100  200  300  400  500  600  700  800  900   
                                   Time (µS)
          
    The pause of 100 µS reliably delays for 100 µS, but the rest of the loop (!outa[16] and repeat) take some
    time to execute also, causing the rising and falling edges to be slightly off of our time reference window.

    If the intention was for the rising and falling edges to be exactly lined up with our time reference window
    of 100 µS, then the MarkSync/WaitSync methods should be used.  The following code performs the same toggling
    task as the previous example (assume T is this Clock object and we are using an accurate, external clock source):

          dira[16]~~
          T.MarkSync
          repeat
            T.WaitSyncUSec(100)
            !outa[16]     
          
    This produces a signal on P16 that looks similar to the following timing diagram.

          P16 ─       
                                                      ... 
                0   100  200  300  400  500  600  700  800  900   
                                   Time (µS)
           
    The MarkSync method marks a reference point in time (0 µS) and each call to WaitSyncUSec(100) waits until
    the next multiple of 100 µS from that reference point.  As long as the loop isn't too long, this effectively
    compensates for the loop's overhead automatically, causing the !outa[16] statement to execute at exact 100 µS
    intervals.       
          
          
          
          
          
          
          
          
          
          
          
          
                         
                                                           
                                                           
                                                           








    
                                                           
                                                           

}}