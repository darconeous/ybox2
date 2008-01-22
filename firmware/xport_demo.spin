CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  buffer_size = 256
  buffer = $8000-buffer_size 'Address where the data buffer should start....

DAT
{
server                   byte "216.35.197.11/80",0 
hostname                 byte "uncommonprojects.com",0    
path                     byte "/proppix/index.php",0
}
server                   byte "192.168.3.2/3000",0 
hostname                 byte "www.anything.com",0         'Only really need this if we are connecting to a server with virtual hosts..
path                     byte "/device/data/2200015933",0  
   
VAR

  
OBJ

  xport       : "xport"
  term        : "tv_terminal"
  data        : "data_parser"
  pause       : "pause"
  
PUB start:channel_idx | field_idx
  term.start(12)     
  'term.out(13)
  'term.out(13)
  
  pause.init
  xport.start(3, 2, 57_600)
  writeln(string("Starting xport demo"))
                       
  writeln(string("getting network address..."))
  
  'Wait for the xport to be ready...                               
  repeat while xport.GetStatus <> xport#ready
  writeln(string("xport ready..."))

  'Send the request...
  xport.Request(@server,@hostname,@path,buffer,buffer_size,TRUE)

  'writeln(string("sending request..."))
   
  repeat while xport.GetStatus <> xport#requesting  
  writeln(string("requesting..."))
  
  repeat while xport.GetStatus <> xport#reading   
  writeln(string("reading..."))

  repeat while xport.GetStatus <> xport#complete  
  writeln(string("done."))

  data.init(buffer)

  repeat channel_idx from 0 to data.GetNumChannels-1
    repeat field_idx from 0 to data.GetNumFields(channel_idx)
      write(data.GetField(channel_Idx,field_idx))
      write(string(":"))
    out(13)                       

 
     
PUB writeln(str_ptr)
  'xport.writeln(str_ptr)
  'term.str(string("    "))
  term.str(str_ptr)
  term.out(13)
  
PUB write(str_ptr)  
  'xport.write(str_ptr)
  term.str(str_ptr)
  
PUB out(char)  
  'xport.out(char)
  term.out(char)