FROM ubuntu:16.04

RUN apt-get update

RUN apt-get install net-tools -y
RUN apt-get install iproute2 -y
RUN apt-get install iputils-ping -y
RUN apt-get install arping -y
RUN apt-get install isc-dhcp-server -y
RUN apt-get install isc-dhcp-client -y
RUN apt-get install iptables -y
RUN apt-get install nano -y
RUN apt-get install build-essential -y
RUN apt-get install libpcap-dev -y
RUN apt-get install tcpdump -y
RUN apt-get install iperf3 -y
RUN apt-get install bridge-utils -y
RUN apt-get install python3 -y
RUN apt-get install python3-pip -y
RUN pip3 install six
RUN apt-get install wget -y
RUN wget https://www.openvswitch.org/releases/openvswitch-2.11.4.tar.gz
RUN tar zxf openvswitch-2.11.4.tar.gz
RUN cd openvswitch-2.11.4 && \
./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc && \
make && \
make install