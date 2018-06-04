# In order to minimize the differences in this file between routers, I am using
# generic aliases where possible. "transit1" refers to the first (and only, at
# this time) transit provider on a given router. This allows standard aliasing
# in the ruleset, confining the majority of the divergence to the alias values.

net_inside4="10.70.32.0/24"
net_inside6="fd00:20::/64"
net_super4="10.0.0.0/8"
net_super6="fd00::/8"
inside_if="vtnet1"
outside_if="vtnet0"


table <self> {self}

######################
# Section 2: Options #
######################

# RST blocked connections
set block-policy drop
# We don't care about OS fingerprinting
set fingerprints "/dev/null"
# Increase state table sizes. Defaults are too small.
set limit { states 200000, frags 20000, src-nodes 20000 }
# Skip pf processing on lo0, just make sure that the default policy
# for inbound to <self> is block
set skip on lo0 

####################################
# Section 3: Traffic Normalization #
####################################

scrub in all 

#######################
# Section 4: Queueing #
#######################

# Nothing to see here folks.

##########################
# Section 5: Translation #
##########################

nat on $outside_if tagged LETMEOUT -> $outside_if:0

#####################
# Section 6: Policy #
#####################

block log all no state
pass out quick on $outside_if tagged LETMEOUT

# Block anything not otherwise permitted from reaching the router itself.
block drop in log from any to <self> no state
# Allow ssh from anywhere, as a safety net.
pass in quick inet proto tcp from any to <self> port 22
pass in quick inet6 proto tcp from any to <self> port 22
pass in quick inet proto icmp from any to <self>
pass in quick inet6 proto icmp6 from any to <self>
pass in quick inet6 proto icmp6 from fe80::/10 to any
pass in quick inet6 proto icmp6 from any to ff00::/8
# BGP
#pass in quick on $inside_if inet proto tcp from $net_inside4 to <self> port 179
#pass in quick on $inside_if inet6 proto tcp from $net_inside6 to <self> port 179
{% if network.bird.bgp.ibgp_sessions is defined %}
# iBGP Sessions must not be tied to a particular interface
{% for session in network.bird.bgp.ibgp_sessions %}
pass in log quick inet proto tcp from {{ session.neighborip4 }} to {{ ipv4_loopback }} port 179
pass in log quick inet6 proto tcp from {{ session.neighborip6 }} to {{ ipv6_loopback }} port 179
pass out log quick inet proto tcp from {{ ipv4_loopback }} to {{ session.neighborip4 }} port 179
pass out log quick inet6 proto tcp from {{ipv6_loopback }} to {{ session.neighborip6 }} port 179
{% endfor %}
{% endif %}
# OSPF
pass in quick on $inside_if inet proto ospf no state
pass in quick on $inside_if inet6 proto ospf no state
# Anything leaving the host is safe enough.
pass out quick from <self> to any

# Allow specific traffic to the outside world
pass in on $inside_if inet proto tcp from $net_super4 to any port {53 80 443} tag LETMEOUT
pass in on $inside_if inet proto udp from $net_super4 to any port {53 123} tag LETMEOUT
pass in on $inside_if inet proto icmp from $net_super4 to any tag LETMEOUT
