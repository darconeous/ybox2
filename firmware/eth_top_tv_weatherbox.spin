{{
  TV Set Top Box for Weather Information - HTTP Client
  $Id: eth_test.spin 290 2007-08-31 20:33:47Z hpham $
  ----------------------------------------------------
  (c) 2006 - 2007 Harrison Pham.
}}

{{
  This file is part of PropTCP.
   
  PropTCP is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.
   
  PropTCP is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
   
  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}}

CON

  _clkmode = xtal1+pll16x
  _xinfreq = 5_000_000

OBJ

  'tcp : "driver_socket"

  tel : "api_telnet_serial"

  tv : "TV_Text"
  
VAR


PUB start | in, gotstart, port

'  tel.start(0,1,2,3,-1,-1,-1,-1)
  tel.start(1,2,3,4,6,7,-1,-1)
  
  tv.start(12)

  'tv.str(string($1,$C,5,"           Austin, TX Weather           ",$C,$8))

  delay_ms(1000)

  port := 20000
  repeat
  
    if port > 30000
      port := 20000

    ++port
    
    tel.connect(208,131,149,67,80,port)
    
    tv.str(string($1,$A,39,$C,1," ",$C,$8))

    tel.resetBuffers
    
    tel.waitConnectTimeout(2000)
     
    if tel.isConnected

      tv.str(string($1,$B,12,"                                       "))
      tv.str(string($1,$A,39,$C,$8," ",$1))

      tel.str(string("GET /?id=124932&pass=sunplant HTTP/1.0",13,10))       ' use HTTP/1.0, since we don't support chunked encoding
      tel.str(string("Host: propserve.fwdweb.com",13,10))
      tel.str(string("User-Agent: PropTCP",13,10))
      tel.str(string("Connection: close",13,10,13,10)) 

      gotstart := false
      repeat
        if (in := tel.rxcheck) > 0
 
          if gotstart AND in <> 10
            tv.out(in)

          if in == $01
            gotstart := true
        else
          ifnot tel.isConnected
            delay_ms(30000)     ' 30 sec delay
            quit
            
    else
      tv.str(string($1,$B,12,$C,$1,"Error: Failed to Connect!",$C,$8))
    
      tel.close
      delay_ms(100)             ' failed to connect, try again in 100ms     

PRI delay_ms(Duration)
  waitcnt(((clkfreq / 1_000 * Duration - 3932)) + cnt)
  