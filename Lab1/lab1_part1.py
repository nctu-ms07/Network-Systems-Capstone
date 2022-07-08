#!/usr/bin/python

from mininet.net import Mininet
from mininet.cli import CLI

def topology():
    net = Mininet()
    
    net.addHost('h1')
    net.addHost('h2')
    net.addHost('h3')
    net.addHost('h4')
    
    net.addSwitch('s1', failMode = 'standalone')
    net.addSwitch('s2', failMode = 'standalone')
    net.addSwitch('s3', failMode = 'standalone')
    
    net.addLink('h1','s1')
    net.addLink('h2','s1')
    
    net.addLink('h3','s3')
    net.addLink('h4','s3')
    
    net.addLink('s1','s2')
    net.addLink('s3','s2')
    
    net.start()
    CLI(net)
    net.stop()
    
if __name__ == '__main__':
    topology()