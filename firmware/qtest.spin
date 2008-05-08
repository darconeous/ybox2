CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
OBJ
  term          : "TV_Text"
  q             : "qring"
VAR
  long stack[100]
  byte qhc
  byte stop
PUB init | qh, err
  term.start(12)
  q.init
  
  term.str(string("Queue Test",13))

  qhc:=q.new
  cognew(feeder(qhc), @stack) 
  stop:=0
  repeat
    err:=\queueTest
    if err
      term.str(string("ERROR: "))
      term.dec(err)
      term.str(string(13))

      'term.str(string("Pages in use: "))
      'term.dec(q.pagesUsed)
      'term.str(string(13))
      dira[9]:=1
      outa[9]:=1
      quit
      delay_ms(5000)
    
        
PUB queueTest | qha,qhb
  repeat while not stop
     
    'delay_ms(500)

    qha:=q.new
    term.str(string("New Queue:"))
    term.dec(qha)
    term.str(string(13))

    qhb:=q.new
    term.str(string("New Queue:"))
    term.dec(qhb)
    term.str(string(13))


    repeat 50
      q.push(qhc,"a")
      q.push(qhc,"b")
      q.push(qhc,"c")
      q.push(qhb,"D")
      q.push(qhb,"E")
      q.push(qhb,"F")
     
    repeat while NOT q.isEmpty(qhb) AND NOT stop
      term.out(q.pull(qhb))
    'repeat while NOT q.isEmpty(qha)
    '  term.out(q.pull(qha))
    '  delay_ms(1)

    repeat 50
      q.push(qhc,"g")
      q.push(qhc,"h")
      q.push(qhc,"i")

    term.out(13)
     
    term.str(string("Done.",13))
    q.delete(qha)
    q.delete(qhb)

PUB feeder(qh) | char
  repeat
    case (char:=\q.pull(qh))
      q#ERR_Q_EMPTY:
        next
      0..255:
        term.out(char)
        next
      other:
        term.str(string("FEEDER ERROR: "))
        term.dec(char)
        term.str(string(13))
        stop:=char
        quit
  
PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)