# A quick and dirty pf rule set to handle redirection of the as123 portable
# subnet.

inside_if="vtnet1"
outside_if="vtnet0"
lo1_ipv4="{{ ipv4_loopback }}"
lo1_ipv6="{{ ipv6_loopback }}"
portable_ipv4="10.123.0.1"
portable_ipv6="fd00:7b::1"


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

rdr on $outside_if from any to $portable_ipv4 -> $lo1_ipv4
rdr on $outside_if from any to $portable_ipv6 -> $lo1_ipv6

#####################
# Section 6: Policy #
#####################
