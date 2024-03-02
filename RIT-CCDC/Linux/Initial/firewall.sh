#!/bin/bash

# # dawg what is the snat and dnat states, im not gonna worry about that
# # use mangle table because it's the first one for packets that are determined to be for this host
# # https://stuffphilwrites.com/wp-content/uploads/2014/09/FW-IDS-iptables-Flowchart-v2019-04-30-1.png 

# # If this Script is not Working check .bashrc or aliases

# # This script assumes that iptables is installed. To verify, run iptables --list or similar.
# # This script is aimed to only have iptables running without any wrappers on it, such as ufw or firewalld.

###########################
## Must run as superuser ##
###########################

if [ "$EUID" -ne 0 ]
  then echo "Must run as superuser"
  exit
fi

# # Import inventory script for service variables, redirect output to null
# # Feature development paused, just manually edit the services below
# source inventory.sh > /dev/null 2>&1

# # Disable UFW as we're handing all firewall stuff in iptables and it's confusing if we manage both
ufw disable

# # Disable firewalld, we're doing everything natively in iptables and sometimes they mix each other up
systemctl stop firewalld
systemctl disable firewalld

################
## Main Rules ##
################

# # Backup Old Rules (iptables -t mangle-restore < backup) [for forensics and etc]
echo "> Backing up old rules"
iptables-save >/etc/ip_rules_old
ip6tables-save >/etc/ip6_rules_old

# Flush Tables
# NAT and RAW tables too? sure, why not
echo "> Flushing Tables"
echo "> If docker is installed, check its rules too."
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X
iptables -t nat -F
iptables -t nat -X
iptables -F
iptables -X
ip6tables -t mangle -F
ip6tables -t mangle -X
ip6tables -t raw -F
ip6tables -t raw -X
ip6tables -t nat -F
ip6tables -t nat -X
ip6tables -F
ip6tables -X

# IPv6 is cringe, block it
echo "> Blocking all IPv6 traffic"
echo "> If you're on IPv6, skill issue. just NAT it more lmao"
ip6tables -t mangle -P INPUT DROP
ip6tables -t mangle -P OUTPUT DROP

# # Ratelimiting
# # Add the following to the end of any rule (and have the rule be a DROP rule):
# -m state --state NEW -m recent --update --seconds 60 --hitcount 6
# # It updates the "recent" list with the source IP address of packets if they match the specified criteria.
# # NEW is important, because limited established traffic would be bad
# # In this case, it will update the "recent" list if the source IP has made 6 connections within the last 60 seconds (1 minute)

# # Block all rate-limited traffic
# # Note: if you have more permissive rate limiting for another rule further down, this one will override it due to it occuring first
# echo "> Block all rate-limited incoming traffic"
# iptables -t mangle -A INPUT -m state --state NEW -m recent --set
# iptables -t mangle -A INPUT -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j LOG --log-prefix "Rate Limit Hit, Dropping Packet: " 
# iptables -t mangle -A INPUT -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j DROP

# # Allow all ESTABLISHED and RELATED. This means we just need to allow NEW connections for each specific rule
# echo "> Allow all established and related traffic"
# iptables -t mangle -A INPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
# iptables -t mangle -A OUTPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT

# # Allow ICMP 
echo "> Allow ICMP"
iptables -t mangle -A INPUT -p ICMP -j ACCEPT
iptables -t mangle -A OUTPUT -p ICMP -j ACCEPT

# # Allow Loopback Traffic
echo "> Allow Loopback Traffic"
iptables -t mangle -A INPUT -i lo -j ACCEPT
iptables -t mangle -A OUTPUT -o lo -j ACCEPT

# # Block Incoming SSH Brute Force
# # The setting of 60 seconds and 6 hits is configured for a scored SSH service scoring 4 times a minute plus blue team access.
# # If SSH is not scored, lower hitcount to something like 3 due to there being fewer legitimate SSH connections.
echo "> Block Inbound SSH Brute Force"
iptables -t mangle -A INPUT -p tcp -m multiport --dports 22 -m state --state NEW -m recent --set
iptables -t mangle -A INPUT -p tcp -m multiport --dports 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j LOG --log-prefix "SSH Rate Limit Hit, Dropping Packet: " 
iptables -t mangle -A INPUT -p tcp -m multiport --dports 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j DROP

# # Allow Incoming SSH
# echo "> Allow Inbound SSH"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 22 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 22 -m state --state ESTABLISHED -j ACCEPT

# # Allow Incoming SSH From Specific Network
echo "> Allow Inbound SSH From Specific Network Only"
iptables -t mangle -A INPUT -p tcp -m multiport --dports 22 -m state --state NEW,ESTABLISHED -s 10.15.1.0/24 -j ACCEPT
iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 22 -m state --state ESTABLISHED -d 10.15.1.0/24 -j ACCEPT

## Allow Scored Service outbound (CCSClient)
## Change `scoring_ip` to the ip of the scoring server and '80,443' to ips of the scored service!
#iptables -t mangle -A OUTPUT -p tcp -d scoring_ip -m multiport --sports 80,443 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -t mangle -A INPUT -p tcp -s scoring_ip -m multiport --dports 80,443 -m state --state ESTABLISHED -j ACCEPT



########################
# OTHER OPTIONAL RULES #
########################

# # Iptables Ranges Examples
# iptables -t mangle -A INPUT -s 10.5.1.0/24 -j ACCEPT
# iptables -t mangle -A INPUT -s 10.5.2.0/24 -j ACCEPT
# iptables -t mangle -A INPUT -s 10.x.x.0/24 -j DROP
# iptables -t mangle -A OUTPUT -s 10.x.x.0/24 -j DROP
# iptables -t mangle -A INPUT -s 10.2.3.4 -j DROP

# # Allow HTTP Outgoing
# echo "> Allow Outbound HTTP"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 80 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 80 -m state --state ESTABLISHED -j ACCEPT

# # Allow HTTP Incoming
# echo "> Allow Inbound HTTP"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 80 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 80 -m state --state ESTABLISHED -j ACCEPT

# # Allow DNS Outgoing (UDP)
# echo "> Allow Outbound DNS (UDP)"
# iptables -t mangle -A OUTPUT -p udp -m multiport --dports 53 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p udp -m multiport --sports 53 -m state --state ESTABLISHED -j ACCEPT

# # Allow DNS Incoming (UDP)
# echo "> Allow Inbound DNS (UDP)"
# iptables -t mangle -A INPUT -p udp -m multiport --dports 53 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p udp -m multiport --sports 53 -m state --state ESTABLISHED -j ACCEPT

# # Allow SSH Outgoing
# echo "> Allow Outbound SSH"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 22 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 22 -m state --state ESTABLISHED -j ACCEPT

# # Allow SSH Outgoing To Specific Network Only
# echo "> Allow Outbound SSH To Specific Network Only"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 22 -m state --state NEW,ESTABLISHED -d NETWORK/24 -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 22 -m state --state ESTABLISHED -s NETWORK/24 -j ACCEPT

# # Allow MariaDB/MySQL Outgoing
# echo "> Allow Outbound MariaDB/MySQL"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 3306 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 3306 -m state --state ESTABLISHED -j ACCEPT

# # Allow MariaDB/MySQL Incoming
# echo "> Allow Inbound MariaDB/MySQL"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 3306 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 3306 -m state --state ESTABLISHED -j ACCEPT

# # Allow Postgresql Outgoing
# echo "> Allow Outbound Postgresql "
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 5432 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 5432 -m state --state ESTABLISHED -j ACCEPT

# # Allow Postgresql Incoming
# echo "> Allow Inbound Postgresql"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 5432 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 5432 -m state --state ESTABLISHED -j ACCEPT

# # Allow Wazuh Outgoing
# echo "> Allow Outbound Wazuh "
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 443,514,1514,1515,1516,9200,9300:9400,55000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 443,514,1514,1515,1516,9200,9300:9400,55000 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p udp -m multiport --dports 514,1514 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p udp -m multiport --sports 514,1514 -m state --state ESTABLISHED -j ACCEPT

# # Allow Wazuh Incoming
# echo "> Allow Inbound Wazuh"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 443,514,1514,1515,1516,9200,9300:9400,55000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 443,514,1514,1515,1516,9200,9300:9400,55000 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p udp -m multiport --dports 514,1514 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p udp -m multiport --sports 514,1514 -m state --state ESTABLISHED -j ACCEPT

# # Allow RHEL IDM clients Outbound
# # Server *shouldn't* be initiating connections... probably. Just change "ESTABLISHED" to "NEW,ESTABLISHED" for INPUT if server initiates
# echo "> Allow RHEL IDM Clients Outbound"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 80,443,389,636,88,464,53,749 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 80,443,389,636,88,464,53,749 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p udp -m multiport --dports 88,464,53,123 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p udp -m multiport --sports 88,464,53,123 -m state --state ESTABLISHED -j ACCEPT

# # Allow RHEL IDM server-server comms
# # Probably not needed if you just have a single server...
# echo "> Allow RHEL IDM Server to Server"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 80,443,389,636,88,464,53,749,7389,9443,9444,9445,8005,8009 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 80,443,389,636,88,464,53,749,7389,9443,9444,9445,8005,8009 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p udp -m multiport --dports 88,464,53,123 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p udp -m multiport --sports 88,464,53,123 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Hashicorp Vault Bidirectional
# 443 is client to load balancer, 8200 incoming is between load balancer and servers, rest are server to server (or server to external api but those vary)
# echo "> Allow Bidirectional Hashicorp Vault"
# iptables -t mangle -A OUTPUT -p tcp --port 8200,8201 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp --port 8200,8201 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Hashicorp Vault Incoming
# echo "> Allow Inbound Hashicorp Vault"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 8200,443 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 8200,443 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Kubernetes Control Plane Incoming
# echo "> Allow Kubernetes Control Plane Incoming"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 6443,2379,2380,10250,10259,10257 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 6443,2379,2380,10250,10259,10257 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Kubernetes Worker Node Incoming
# echo "> Allow Kubernetes Control Plane Incoming"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 10250,30000:32767 -m state --state ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 10250,30000:32767 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Gitlab Bidirectional (not sure which direction we need...)
# 5050 is also needed for remote access to container registry but that's (mostly?) optional, plus any additional services
# echo "> Allow Gitlab Bidirectional"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 80,443 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 80,443 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow Grafana Bidirectional
# echo "> Allow Grafana Bidirectional"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 3000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 3000 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow IMAP/S Incoming (For Server)
# # 143 is unencrypted, 993 is encrypted
# echo "> Allow IMAP/S Incoming"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 143,993 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 143,993 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow IMAP/S Outbound (For Client)
# # 143 is unencrypted, 993 is encrypted
# echo "> Allow IMAP/S Outbound"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 143,993 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 143,993 -m state --state NEW,ESTABLISHED -j ACCEPT

# # Allow SMTP/S Incoming (For Server)
# # 25 is unencrypted, 587 is encrypted, 465 is outdated encrypted
# echo "> Allow SMTP/S Incoming"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 25,587,465 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 25,587,465 -m state --state ESTABLISHED -j ACCEPT

# # Allow SMTP/S Outbound (For Client)
# # 25 is unencrypted, 587 is encrypted, 465 is outdated encrypted
# echo "> Allow SMTP/S Outbound"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 25,587,465 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 25,587,465 -m state --state ESTABLISHED -j ACCEPT

# # Allow IRC Inbound (For Server)
# echo "> Allow IRC Inbound"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 194,529,994,6660:7000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 194,529,994,6660:7000 -m state --state ESTABLISHED -j ACCEPT

# # Allow IRC Outgoing (For Client)
# echo "> Allow IRC Outgoing"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 194,529,994,6660:7000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --sports 194,529,994,6660:7000 -m state --state ESTABLISHED -j ACCEPT

# # Allow FTP Inbound (For Server)
# echo "> Allow FTP Inbound"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 20,21 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 20,21 -m state --state ESTABLISHED -j ACCEPT

# # Allow FTP Outbound (For Client)
# echo "> Allow FTP Outbound"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 20,21 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 20,21 -m state --state ESTABLISHED -j ACCEPT

# # Allow FTPS Inbound (For Server)
# echo "> Allow FTPS Inbound"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 989,990 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 989,990 -m state --state ESTABLISHED -j ACCEPT

# # Allow FTPS Outbound (For Client)
# echo "> Allow FTPS Outbound"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 989,990 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 989,990 -m state --state ESTABLISHED -j ACCEPT

# # Allow Datadog
# # "Datadog agent sends all of its logs to the cloud server using https"
# # inbound on loopback
# # outbound to any of the hosts on https://ip-ranges.us5.datadoghq.com/
echo "> Allow Datadog"
iptables -t mangle -A OUTPUT -d 34.149.66.128/26 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.66.128/26 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.125.158/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.125.158/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 35.190.51.116/32 -j ACCEPT
iptables -t mangle -A INPUT -s 35.190.51.116/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.119.85/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.119.85/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.203.90/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.203.90/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.110.187.75/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.110.187.75/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.117.129.254/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.117.129.254/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.66.131/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.66.131/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.54.227/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.54.227/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.66.128/26 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.66.128/26 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.7.29/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.7.29/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.40.115/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.40.115/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.41.148/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.41.148/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.125.158/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.125.158/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.160.150.109/32 -j ACCEPT
iptables -t mangle -A INPUT -s 34.160.150.109/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 35.190.51.116/32 -j ACCEPT
iptables -t mangle -A INPUT -s 35.190.51.116/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 35.244.255.175/32 -j ACCEPT
iptables -t mangle -A INPUT -s 35.244.255.175/32 -j ACCEPT
iptables -t mangle -A OUTPUT -d 34.149.66.128/26 -j ACCEPT
iptables -t mangle -A INPUT -s 34.149.66.128/26 -j ACCEPT

# # Accept Various Port Incoming
# echo "> Various Port Incoming"
# iptables -t mangle -A INPUT -p tcp -m multiport --dports 8000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 8000 -m state --state ESTABLISHED -j ACCEPT

# # Allow Various Port Outgoing
# echo "> Various Port Outgoing"
# iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 3000 -m state --state NEW,ESTABLISHED -j ACCEPT
# iptables -t mangle -A INPUT  -p tcp -m multiport --sports 3000 -m state --state ESTABLISHED -j ACCEPT


##################
## Ending Rules ##
##################

# # Log All Traffic If Not Matching
echo "> Log non-matching traffic"
iptables -t mangle -A INPUT -j LOG --log-prefix "Packet dropped: "
iptables -t mangle -A OUTPUT -j LOG --log-prefix "Packet dropped: "

# # Drop All Traffic If Not Matching
echo "> Drop non-matching traffic : Connection may drop"
iptables -t mangle -A INPUT -j DROP
iptables -t mangle -A OUTPUT -j DROP

# # Backup Rules (iptables -t mangle-restore < backup)
echo "> Backing up rules"
iptables-save >/etc/ip_rules_new
ip6tables-save >/etc/ip6_rules_new

# # Anti-Lockout Rule
# # If user gets locked out by the drop all, then this will run and cancel the changes
echo "> Sleep Initiated : Cancel Program to prevent flush"
echo "> pssst: this means to cancel the program to save the firewall changes"
sleep 15
iptables -t mangle -F
echo "> Anti-Lockout executed : Rules have been flushed"
