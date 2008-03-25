PUB make_dhcp_packet(msg_type, local_macaddr,ip_addr, outputfunc, pkt_id)  | i

  nic.wr_frame($45)        ' ip vesion and header size
  
  nic.wr_frame($00)        ' TOS
  
  nic.wr_frame($01)
  nic.wr_frame($48)  ' IP Packet Length

  nic.wr_frame(pkt_id >> 8)                                               ' Used for fragmentation
  nic.wr_frame(pkt_id)

  nic.wr_frame($40)  ' Don't fragment
  nic.wr_frame($00)  ' frag stuff

  nic.wr_frame($FF)  ' TTL
  nic.wr_frame(PROT_UDP)  ' UDP

  nic.wr_frame($00)
  nic.wr_frame($00)  ' header checksum (Filled in by hardware)
  
  ' source IP address (all zeros
  repeat i from 0 to 3
    nic.wr_frame($00)

  ' dest IP address (broadcast)
  repeat i from 0 to 3
    nic.wr_frame($FF)

  nic.wr_frame(00)  ' Source Port
  nic.wr_frame(68)  ' UDP

  nic.wr_frame(00)  ' Dest Port
  nic.wr_frame(67)  ' UDP

  nic.wr_frame($01)
  nic.wr_frame($34)  ' UDP packet Length


  nic.wr_frame($00)
  nic.wr_frame($00)  ' UDP checksum

  nic.wr_frame($01) ' op (bootrequest)
  nic.wr_frame($01) ' htype
  nic.wr_frame($06) ' hlen
  nic.wr_frame($00) ' hops

  ' xid
  nic.wr_frame($00)
  nic.wr_frame($00)
  nic.wr_frame(pkt_id >> 8)
  nic.wr_frame(pkt_id)

  nic.wr_frame($00) ' secs
  nic.wr_frame($7F) ' secs

  nic.wr_frame($00) ' padding
  nic.wr_frame($00) ' padding

  repeat i from 0 to 3
    nic.wr_frame(ip_addr[i]) 'ciaddr
  repeat i from 0 to 3
    nic.wr_frame(0) 'yiaddr
  repeat i from 0 to 3
    nic.wr_frame(0) 'siaddr
  repeat i from 0 to 3
    nic.wr_frame(0) 'giaddr

  ' source mac address
  repeat i from 0 to 5
    nic.wr_frame(local_macaddr[i])
  repeat i from 0 to 9
    nic.wr_frame(0)

  repeat i from 0 to 63
    nic.wr_frame(0) 'sname

  repeat i from 0 to 127
    nic.wr_frame(0) ' file
  
  ' DHCP Magic Cookie
  nic.wr_frame($63)
  nic.wr_frame($82)
  nic.wr_frame($53)
  nic.wr_frame($63)

  ' DHCP Message Type
  nic.wr_frame(53)
  nic.wr_frame($01)
  nic.wr_frame(msg_type)

  ' DHCP Client-ID
  nic.wr_frame(61)
  nic.wr_frame($07)
  nic.wr_frame($01)
  repeat i from 0 to 5
    nic.wr_frame(local_macaddr[i])

  ' End of vendor data
  nic.wr_frame($FF)

  repeat i from 0 to 46
    nic.wr_frame(0) 'vend

