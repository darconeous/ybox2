CON

  channel_max     = 8
VAR
  long channel_field_lengths[channel_max]
  long channels[channel_max]        'pointer to channels data (in buffer)
  byte num_chans                    'the number of channels

  
PUB Init(data_buffer) | buffer_idx,channel_idx,temp_char   
  buffer_idx := 0
  channel_idx :=0
  num_chans :=0
  bytefill(@channel_field_lengths[0],0,channel_max)                    
  repeat while byte[data_buffer+buffer_idx] <> 0
    temp_char := byte[data_buffer+buffer_idx]
    if temp_char == 0
      quit                
    elseif temp_char == 60 '<
      'New channel starts at next char                
      channels[channel_idx] := data_buffer+buffer_idx+1
    elseif temp_char == 62 '>
      channel_idx++
      num_chans++
      byte[data_buffer+buffer_idx] := 0
    elseif temp_char == 44 ',
      channel_field_lengths[channel_idx]++ 
      byte[data_buffer+buffer_idx] := 0
      
    buffer_idx++

PUB GetNumChannels:n
  n := num_chans

PUB GetNumFields(channel):n
  n := channel_field_lengths[channel]
  
PUB GetField(channel,field):str_ptr | pos
   pos := channels[channel]                
   repeat field
     pos := pos + strsize(pos)+1 
   str_ptr := pos