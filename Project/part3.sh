#!/bin/bash
docker exec BRGr ip addr add 140.113.0.3/16 dev BRGrR1

ip link add BRG1br0_2 type veth peer name br0BRG1_2
ip link set br0BRG1_2 master br0
ip link set BRG1br0_2 netns $(docker inspect --format='{{.State.Pid}}' BRG1)
ip link set br0BRG1_2 up
docker exec BRG1 ip link set BRG1br0_2 up

docker exec BRG1 dhclient BRG1br0_2

docker exec BRG1 ip route add 140.113.0.3/32 via 172.27.0.1 dev BRG1br0_2

BRG1_ip=$(docker exec BRG1 ifconfig BRG1br0_2 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

docker exec BRG1 ip fou add port 33333 ipproto 47
docker exec BRG1 bash -c "ip link add GRETAP_2 type gretap remote 140.113.0.3 local $BRG1_ip key 33333 encap fou encap-sport 33333 encap-dport 33330"
docker exec BRG1 ip link set GRETAP_2 up
docker exec BRG1 ovs-vsctl add-port br1 GRETAP_2
docker exec BRG1 ovs-ofctl -O OpenFlow13 mod-group br1 group_id=1,type=fast_failover,bucket=watch_port:GRETAP_1,output:GRETAP_1,bucket=watch_port:GRETAP_2,output:GRETAP_2
docker exec BRG1 ovs-ofctl add-flow br1 in_port=GRETAP_2,actions=output:BRG1h1