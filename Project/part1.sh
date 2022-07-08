#!/bin/bash

docker_build() {
    docker run --detach --interactive --privileged  \
    --network none --cap-add NET_ADMIN --cap-add NET_BROADCAST \
    --name ${1} project
}

iptables -P FORWARD ACCEPT

docker_build h1
docker_build h2
docker_build BRG1
docker_build BRG2
ip link add br0 type bridge
ip link set br0 up
docker_build edge
docker_build R1
docker_build BRGr

ip link add h1BRG1 type veth peer name BRG1h1
ip link add h2BRG2 type veth peer name BRG2h2
ip link add BRG1br0_1 type veth peer name br0BRG1_1
ip link add BRG2br0 type veth peer name br0BRG2
ip link add br0edge type veth peer name edgebr0
ip link add edgeR1 type veth peer name R1edge
ip link add R1BRGr type veth peer name BRGrR1
ip link add BRGrGWr type veth peer name GWrBRGr

ip link set br0BRG1_1 master br0
ip link set br0BRG2 master br0
ip link set br0edge master br0

ip link set h1BRG1 netns $(docker inspect --format='{{.State.Pid}}' h1)
ip link set h2BRG2 netns $(docker inspect --format='{{.State.Pid}}' h2)
ip link set BRG1br0_1 netns $(docker inspect --format='{{.State.Pid}}' BRG1)
ip link set BRG2br0 netns $(docker inspect --format='{{.State.Pid}}' BRG2)
ip link set edgeR1 netns $(docker inspect --format='{{.State.Pid}}' edge)
ip link set R1BRGr netns $(docker inspect --format='{{.State.Pid}}' R1)
ip link set BRGrGWr netns $(docker inspect --format='{{.State.Pid}}' BRGr)
ip link set BRG1h1 netns $(docker inspect --format='{{.State.Pid}}' BRG1)
ip link set BRG2h2 netns $(docker inspect --format='{{.State.Pid}}' BRG2)
ip link set edgebr0 netns $(docker inspect --format='{{.State.Pid}}' edge)
ip link set R1edge netns $(docker inspect --format='{{.State.Pid}}' R1)
ip link set BRGrR1 netns $(docker inspect --format='{{.State.Pid}}' BRGr)

docker exec edge ip addr add 172.27.0.1/24 dev edgebr0
docker exec edge ip addr add 140.114.0.1/16 dev edgeR1
docker exec R1 ip addr add 140.114.0.2/16 dev R1edge
docker exec R1 ip addr add 140.113.0.1/16 dev R1BRGr
docker exec BRGr ip addr add 140.113.0.2/16 dev BRGrR1
ip addr add 20.0.1.1/24 dev GWrBRGr

docker exec h1 ip link set h1BRG1 up
docker exec h2 ip link set h2BRG2 up
docker exec BRG1 ip link set BRG1br0_1 up
docker exec BRG2 ip link set BRG2br0 up
ip link set br0edge up
docker exec edge ip link set edgeR1 up
docker exec R1 ip link set R1BRGr up
docker exec BRGr ip link set BRGrGWr up
docker exec BRG1 ip link set BRG1h1 up
docker exec BRG2 ip link set BRG2h2 up
ip link set br0BRG1_1 up
ip link set br0BRG2 up
docker exec edge ip link set edgebr0 up
docker exec R1 ip link set R1edge up
docker exec BRGr ip link set BRGrR1 up
ip link set GWrBRGr up

docker exec BRG1 sysctl net.ipv4.ip_forward=1
docker exec BRG1 sysctl -p
docker exec BRG2 sysctl net.ipv4.ip_forward=1
docker exec BRG2 sysctl -p
docker exec edge sysctl net.ipv4.ip_forward=1
docker exec edge sysctl -p
docker exec R1 sysctl net.ipv4.ip_forward=1
docker exec R1 sysctl -p
docker exec BRGr sysctl net.ipv4.ip_forward=1
docker exec BRGr sysctl -p

docker exec BRGr ip route add default dev BRGrGWr

docker exec edge ip route add 140.113.0.0/16 via 140.114.0.2
docker exec BRGr ip route add 140.114.0.0/16 via 140.113.0.1

docker cp dhcpd_edge.conf edge:/root/dhcpd_edge.conf
docker exec edge touch /var/lib/dhcp/dhcpd.leases
docker exec edge /usr/sbin/dhcpd 4 -pf /run/dhcp-server-dhcpd.pid -cf /root/dhcpd_edge.conf edgebr0
docker exec edge iptables -t nat -A POSTROUTING -p udp -s 172.27.0.0/24 -j SNAT --to-source 140.114.0.1

/usr/sbin/dhcpd 4 -pf /run/dhcp-server-dhcpd.pid -cf ./dhcpd.conf GWrBRGr
iptables -t nat -A POSTROUTING -s 20.0.1.0/24 -j MASQUERADE

docker exec BRG1 dhclient BRG1br0_1
docker exec BRG2 dhclient BRG2br0

docker exec BRG1 ip route add 140.113.0.2/32 via 172.27.0.1 dev BRG1br0_1

BRG1_ip=$(docker exec BRG1 ifconfig BRG1br0_1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
BRG2_ip=$(docker exec BRG2 ifconfig BRG2br0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

modprobe fou
docker exec BRG1 ip fou add port 11111 ipproto 47
docker exec BRG1 bash -c "ip link add GRETAP_1 type gretap remote 140.113.0.2 local $BRG1_ip key 11111 encap fou encap-sport 11111 encap-dport 11110"
docker exec BRG1 ip link set GRETAP_1 up
docker exec BRG1 ip link add br0 type bridge
docker exec BRG1 ip link set BRG1h1 master br0
docker exec BRG1 ip link set GRETAP_1 master br0
docker exec BRG1 ip link set br0 up

docker exec BRG2 ip fou add port 22222 ipproto 47
docker exec BRG2 bash -c "ip link add GRETAP type gretap remote 140.113.0.2 local $BRG2_ip key 22222 encap fou encap-sport 22222 encap-dport 22220"
docker exec BRG2 ip link set GRETAP up
docker exec BRG2 ip link add br0 type bridge
docker exec BRG2 ip link set BRG2h2 master br0
docker exec BRG2 ip link set GRETAP master br0
docker exec BRG2 ip link set br0 up

docker cp main.cpp BRGr:/root/main.cpp
docker exec BRGr g++ -std=c++14 /root/main.cpp -o /root/main -lpcap
docker exec -it BRGr ./root/main