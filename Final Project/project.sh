#!/bin/sh

#ofp_header - 8 bytes
#  uint8_t version;    OFP_VERSION
#  uint8_t type;       One of the OFPT_ constants
#  uint16_t length;    Length including this ofp_header
#  uint32_t xid;       Transaction id associated with this packet.
#                      Replies use the same id as was in the request
#                      to facilitate pairing

while :
do
	data=$(iw dev wlan0 station dump | grep -E 'Station|signal' | 
	awk '{
		for(i=1; i<=NF; i++) {
			if($i=="Station") {
				print $(i + 1)
			}
			
			if($i=="signal:") {
				print $(i + 1)
			}
		}
	}');
	pkt_length=$((8 + $(echo -n "${data}" | wc -c)));
	hex_pkt_length=$(printf '%04x' ${pkt_length});

	echo -e "\x04\x02\x${hex_pkt_length:0:1}\x${hex_pkt_length:2:3}\x00\x00\x00\x00${data}\c" | nc 192.168.2.100 6653;
	sleep 20;
done;