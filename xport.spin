CON
      
       
  'Networking status
  not_ready       = 0
  ready           = 1   
  connecting      = 2 
  requesting      = 3 
  reading         = 4
  complete        = 5


  'Error codes
  no_err          = 0 
  connect_failed  = 1
  connect_dropped = 2
  request_failed  = 3
  buffer_overflow = 4
 
VAR
  long cog                                 
  long stack[48] 'Stack space for new cog
  
  byte status                                                   
  byte err
  long server_str
  long host_name_str
  long path_str
  long buffer_addr
  long buff_size          
  long content_length

  byte ignore_remaining  
  
OBJ

  'term          : "tv_terminal"     
  xport_uart    : "FullDuplexSerial" 
  pause         : "pause"
  numbers       : "Numbers"
     
PUB Start(rxpin, txpin, baudrate): okay
  stop
  
  'term.start(12) 
  'term.out(13)
  'term.out(13)                         
  
  pause.init
  numbers.init
                          
  'xport_uart.start(3, 2, $0000, baudrate)
  xport_uart.start(rxpin, txpin, $0000, baudrate)
  okay := cog := cognew(Main, @stack) + 1
  
PUB Stop      
  if cog
    cogstop(cog~ - 1)
  xport_uart.stop
  'term.stop
  
PUB GetStatus:the_status
  the_status := status

PUB GetErr:e
  e := err

PUB ResetErr
  err := 0
    
PUB Request(_server_str,_host_name_str,_path_str,_buffer_addr,_buff_size,_clear_buffer)


  if status <> ready AND status <> complete    
    return
  ignore_remaining := FALSE  
  server_str := _server_str
  host_name_str := _host_name_str
  path_str := _path_str
  buffer_addr := _buffer_addr
  buff_size := _buff_size
  content_length := 0
  if _clear_buffer
    bytefill(buffer_addr,0,buff_size) 
  status := connecting

PUB ClearRequest
  if status == complete
    status := ready

PUB IgnoreRemainingBytes
  if status <> ready AND status <> complete               
    ignore_remaining := TRUE
  
PRI Reset | byte_in
 
  ' Reset pin on the Xport is pin 4
  dira[4] := 1 
  outa[4] := 0
  'pause.pause(100)
  outa[4] := 1
  status := not_ready
  byte_in := 0
  content_length := 0
  'Wait for D
  repeat while byte_in <> 68  
    byte_in := xport_uart.rxcheck

  status := ready
  
PRI Main  | byte_in, buffer_idx 

  reset

  repeat
    'Wait here til we get a request...
    repeat while status <> connecting
      pause.pause(100)
      'writeln(string("WAITING")) 
    
    buffer_idx := 0 
     
    'writeln(string("CONNECTING..."))                 
     
    byte_in := 0
    'writeln(server_str)        
    'xport_uart.str(string("C192.168.3.2/3000",13))
    xport_uart.tx(67)
    xport_uart.str(server_str)
    xport_uart.tx(13)
     
    'Wait for C, D, or N
    ' TODO: handle connection error/timeout...
    repeat              
      byte_in := xport_uart.rx
      if byte_in == 67
        quit
      elseif byte_in == 78
        err := connect_failed
        pause.pause(500)
      elseif byte_in == 68
        err := connect_dropped
        pause.pause(500)
      xport_uart.tx(67)
      xport_uart.str(server_str)
      xport_uart.tx(13)
      
      
    status := requesting
    'writeln(string("ABOUT TO REQUEST..."))                      
    'xport_uart.str(string("GET /device/data/2200015933 HTTP/1.0",13,10,13,10))
 
    xport_uart.str(string("GET "))
    xport_uart.str(path_str)                        
    xport_uart.str(string(" HTTP/1.0",13,10))
    xport_uart.str(string("HOST:"))
    xport_uart.str(host_name_str)    
    xport_uart.str(string(13,10,13,10))

    buffer_idx := 0

    'Read header until we get to the 'Content-Length: ' header
    repeat while not waitfor(string("Content-Length: "),16)

    repeat
      byte_in := xport_uart.rx
      if byte_in > 0
        if byte_in == 13
          quit
        byte[buffer_addr][buffer_idx] := byte_in
        buffer_idx++ 

    content_length := numbers.FromStr(buffer_addr,Numbers#DEC)

    'Wait for end of header (2 CRLF's)
    repeat while not waitfor(string(10,13,10),3)
        
    ' Reset buffer
    buffer_idx := 0  
    status := reading
    repeat

      'xport_uart.tx($11)
      byte_in := xport_uart.rxcheck
      'xport_uart.tx($13)
      if (byte_in <> -1)
        'write(numbers.toStr(buffer_idx,Numbers#DEC))
        'out(46)  
        if buffer_idx < buff_size
          if not ignore_remaining 
            byte[buffer_addr][buffer_idx] := byte_in

        buffer_idx++
        if buffer_idx == content_length 
          quit
        'if buffer_idx == buff_size
        ' buffer overflow...TODO: set a flag here?
          'writeln(string("buffer over run..."))

    'writeln(string("Finished reading body..."))

    'Wait for Disconnect (D from lantronix)
    repeat while byte_in <> 68
      byte_in := xport_uart.rx

    ignore_remaining := FALSE  
    status := complete
    'pause.pause(4000)
    'status := ready

PRI waitfor(str_ptr,size):finished | Index, byte_in
  byte_in := 0
  repeat Index from 0 to size-1
    byte_in := xport_uart.rx
    if byte_in <> byte[str_ptr][Index]
      finished := FALSE
      return
  finished := TRUE
       
  

{ 
PUB writeln(str_ptr)
  'term.str(string("    "))
  term.str(str_ptr)
  term.out(13)        

PUB write(str_ptr)
  term.str(str_ptr)
  

PUB out(char)
  term.out(char)
}  