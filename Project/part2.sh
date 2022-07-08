#!/bin/bash
docker exec BRG1 ip link delete br0
docker exec BRG1 /usr/share/openvswitch/scripts/ovs-ctl start
docker exec BRG1 ovs-vsctl add-br br1
docker exec BRG1 ip link set br1 up
docker exec BRG1 ovs-vsctl add-port br1 BRG1h1
docker exec BRG1 ovs-vsctl add-port br1 GRETAP_1
docker exec BRG1 ovs-ofctl -O OpenFlow13 add-meter br1 meter=1,kbps,band=type=drop,rate=1000
docker exec BRG1 ovs-ofctl -O OpenFlow13 add-group br1 group_id=1,type=fast_failover,bucket=watch_port:GRETAP_1,output:GRETAP_1
docker exec BRG1 ovs-ofctl del-flows br1
docker exec BRG1 ovs-ofctl -O OpenFlow13 add-flow br1 in_port=BRG1h1,actions=meter:1,group:1
docker exec BRG1 ovs-ofctl add-flow br1 in_port=GRETAP_1,actions=output:BRG1h1
