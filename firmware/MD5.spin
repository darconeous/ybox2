{{
  MD5 Hash in Spin
  Robert Quattlebaum <darco@deepdarc.com>

  See http://en.wikipedia.org/wiki/MD5 for more information on the MD5 hash algorithm.
}}
{ HASH PSEUDO CODE:
//Note: All variables are unsigned 32 bits and wrap modulo 2^32 when calculating
var int[64] r, k

//r specifies the per-round shift amounts
r[ 0..15] := {7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22} 
r[16..31] := {5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20}
r[32..47] := {4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23}
r[48..63] := {6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21}

//Use binary integer part of the sines of integers (Radians) as constants:
for i from 0 to 63
    k[i] := floor(abs(sin(i + 1)) × (2 pow 32))

//Initialize variables:
var int h0 := 0x67452301
var int h1 := 0xEFCDAB89
var int h2 := 0x98BADCFE
var int h3 := 0x10325476

//Pre-processing:
append "1" bit to message
append "0" bits until message length in bits ≡ 448 (mod 512)
append bit (bit, not byte) length of unpadded message as 64-bit little-endian integer to message

//Process the message in successive 512-bit chunks:
for each 512-bit chunk of message
    break chunk into sixteen 32-bit little-endian words w[i], 0 ≤ i ≤ 15

    //Initialize hash value for this chunk:
    var int a := h0
    var int b := h1
    var int c := h2
    var int d := h3

    //Main loop:
    for i from 0 to 63
        if 0 ≤ i ≤ 15 then
            f := (b and c) or ((not b) and d)
            g := i
        else if 16 ≤ i ≤ 31
            f := (d and b) or ((not d) and c)
            g := (5×i + 1) mod 16
        else if 32 ≤ i ≤ 47
            f := b xor c xor d
            g := (3×i + 5) mod 16
        else if 48 ≤ i ≤ 63
            f := c xor (b or (not d))
            g := (7×i) mod 16
 
        temp := d
        d := c
        c := b
        b := b + leftrotate((a + f + k[i] + w[g]) , r[i])
        a := temp

    //Add this chunk's hash to result so far:
    h0 := h0 + a
    h1 := h1 + b 
    h2 := h2 + c
    h3 := h3 + d

var int digest := h0 append h1 append h2 append h3 //(expressed as little-endian)
}

CON { Public Constants }
  HASH_LENGTH = 16 ' An MD5 hash is 16 bytes long
  BLOCK_LENGTH = 64 ' Block length is 64 bytes  
DAT { Tables }

k       long  $D76AA478, $E8C7B756, $242070DB, $C1BDCEEE, $F57C0FAF, $4787C62A, $A8304613, $FD469501
        long  $698098D8, $8B44F7AF, $FFFF5BB1, $895CD7BE, $6B901122, $FD987193, $A679438E, $49B40821
        long  $F61E2562, $C040B340, $265E5A51, $E9B6C7AA, $D62F105D, $02441453, $D8A1E681, $E7D3FBC8
        long  $21E1CDE6, $C33707D6, $F4D50D87, $455A14ED, $A9E3E905, $FCEFA3F8, $676F02D9, $8D2A4C8A
        long  $FFFA3942, $8771F681, $6D9D6122, $FDE5380C, $A4BEEA44, $4BDECFA9, $F6BB4B60, $BEBFBC70
        long  $289B7EC6, $EAA127FA, $D4EF3085, $04881D05, $D9D4D039, $E6DB99E5, $1FA27CF8, $C4AC5665
        long  $F4292244, $432AFF97, $AB9423A7, $FC93A039, $655B59C3, $8F0CCC92, $FFEFF47D, $85845DD1
        long  $6FA87E4F, $FE2CE6E0, $A3014314, $4E0811A1, $F7537E82, $BD3AF235, $2AD7D2BB, $EB86D391
         
r       byte  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22
        byte  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20
        byte  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23
        byte  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21

initial_hash long $67452301, $EFCDAB89, $98BADCFE, $10325476


PUB hash(dataptr,datalen,h)
  hashstart(h)
  hashfinish(dataptr,datalen,datalen,h)
  
PUB hashStart(h)
  bytemove(h,@initial_hash,HASH_LENGTH)
  
PUB hashBlock(dataptr,h)|i,a,b,c,d,f,g,tmp
  bytemove(@a,h,HASH_LENGTH)
  repeat i from 0 to 63
    case i
      0 .. 15:
        f := (b & c) | ((! b) & d)
        g := i
      16 .. 31:
        f := (d & b) | ((! d) & c)
        g := (5*i + 1) & 15
      32 .. 47:
        f := b ^ c ^ d
        g := (3*i + 5) & 15
      48 .. 63:
        f := c ^ (b | (! d))
        g := (7*i) & 15

    tmp := d
    d := c
    c := b
    b += (a + f + k[i] + LONG[dataptr][g]) <- r[i]
    a := tmp
     
  LONG[h][0]+=a
  LONG[h][1]+=b
  LONG[h][2]+=c
  LONG[h][3]+=d
         
PUB hashFinish(dataptr,datalen,totallen,h):i|a[BLOCK_LENGTH/4]
  repeat while datalen => BLOCK_LENGTH
    hashBlock(dataptr,h)
    datalen-=BLOCK_LENGTH
    dataptr+=BLOCK_LENGTH
  bytefill(@a,0,BLOCK_LENGTH)
  bytemove(@a,dataptr,datalen)
  BYTE[@a][datalen]:=$80
  if datalen>BLOCK_LENGTH-9
    hashBlock(@a,h)     
    bytefill(@a,0,BLOCK_LENGTH)
  LONG[@a][14]:=totallen*8
  hashBlock(@a,h)     
  