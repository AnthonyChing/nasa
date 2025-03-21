# A Setup Guide for Alpine Linux on Virtual Box
## Steps
1. Attach NAT to the network interface
```bash
setup-interfaces               # 按到底
service networking restart
setup-apkrepos                 # choose nycu (35)
apk update
apk add openssh vlan vim       # vim is optional
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
service sshd start
passwd                         # set password for ssh
```
2. Attach Host-only network to the network interface
```bash
vim /etc/network/interfaces
auto eth0.11
iface eth0.11 inet static
    address 10.30.11.10
    netmask 255.255.255.0
    gateway 10.30.11.1
	mtu 1400
service networking restart
ip addr del 10.0.2.15 dev eth0
vim /etc/resolv.conf
nameserver 8.8.8.8
```
Create a NAT Network and attach OPNsense to the NAT network
## Install Alpine Linux onto a Virtual Disk
```bash
setup-alpine
keyboard layout: us
keyboard variant: us-mac
Hostname: localhost
Interface: eth0.99
IP: 10.30.99.10
Netmask: 255.255.255.0
Gateway: 10.30.99.1
done
n
DNS domain name: dns.google
nameserver: 8.8.8.8
Root password: root
Root password: root
Timezone: ROC
none
chrony? -> none
```