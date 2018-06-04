#jinja2: lstrip_blocks: True
###########################################################################
#                                                                         #
# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING #
#                                                                         #
# This file is managed by ansible. Do not make local modifications to it  #
# If you do, your changes will get nuked by the next ansible run!         #
###########################################################################

# This configuration file includes configuration that is common for all BGP
# speakers (v6 only). Not all is used on all routers.

## Shared functions

# Functions and filters for BGP routes. Based on the recommended practices laid
# out in the BIRD filtering example.
# https://gitlab.labs.nic.cz/bird/wikis/BGP_filtering

function rt_import_all(int asn) {
	# A more permissive function to handle prefixes received from uplinks.
	# We will not know about all of the prefixes we receive.

	# The first hop in the path must match the ASN of the sending router.
	if bgp_path.first != asn then return false;
	# Path must be no longer than 64.
	if bgp_path.len > 64 then return false;
	# Next hop IP must match router sending route.
	if bgp_next_hop != from then return false;
	# If all else fails, route is okay.
	return true;
}

function rt_import_rs(int asn) {
	# An even more permissive function, for processing updates from route
	# servers. The adjacency checks are meaningless here.

	# Path must be no longer than 64.
	if bgp_path.len > 64 then return false;
	# If all else fails, route is okay.
	return true;
}

## Protocol templates

template bgp ebgp6 {
	# This is a standard template for defining BGP sessions. It should be
	# useable for any protocol instance, with local modifcations going in
	# the protocol instance defintion.
	#
	# TRAFFIC MIGRATION
	# This template contains configuration that can be used to migrate
	# traffic off this router, for maintenance, upgrades, whatever. There
	# are two sections below that must be uncommented. The "preference" line
	# controls how BIRD manages route import from BGP protocols. The defailt
	# is 100, so setting 99 causes BIRD to prefer any other BGP-learned
	# instance of a prefix. To encourage upstream routers to use alternate
	# paths, uncomment the bgp_path lines in the export filter. This should
	# cause most routers to prefer another path (but is not guaranteed).
	#
	# Once these lines are configured, activate the changes in birdc by
	# running the "configure" command. Testing shows that this change is
	# minimally disruptive.

        # Reasonable logging.
        debug { states, routes, interfaces, events, packets };

        # Set our local AS.
        local as myas;

{% if network.bird.bgp is defined and network.bird.bgp.allow_myas|default(False) %}
        # Allow the local AS to appear once in the ASpath. This is a hack
        # to simply allow us to see opposite site prefixes via eBGP, without
        # iBGP sessions, a PtP link, etc.
        allow local as 1;
{% endif %}

	{% if nerf_me is defined and nerf_me %}
	# Do not remove this line. This directive tells BIRD to reduce the
	# priority of the protocol instance (or in this case, all instances that
	# use the template) from the default of 100. This prevents routes from
	# this protocol from being selected as outbound paths.
	preference 99;
	{% endif %}

	# Default: 240. Set lower for demonstration expediency.
        hold time {{ bgp_hold_time|default('240') }};

	# This import filter is oversimplified for demonstration. You should be
	# doing sanity checks on received routes!
	import filter {
	{% if nerf_me is defined and nerf_me %}
		bgp_local_pref=90;
	{% endif %}
		accept;
	};
        # Export exactly what prefixes we want advertised. No surprises.
        export filter {
                if proto = "static_bgp_v6" || proto = "standby_bgp_v6" || proto = "portable_bgp_v6" && net.len <= 48 then {
			{% if nerf_me is defined and nerf_me %}
			# These lines cause our AS to be prepended 5 times, in
			# hope of preventing the BGP instance from being
			# preferred by upstream.
			bgp_path.prepend(myas);
			bgp_path.prepend(myas);
			bgp_path.prepend(myas);
			bgp_path.prepend(myas);
			bgp_path.prepend(myas);
			{% endif %}
			accept;
		}
{% if network.bird.bgp is defined and network.bird.bgp.transit_as|default(False) %}
		# Transit routers should pass along routes learned by BGP. This
		# approximates the behavior of a transit provider for the
		# purposes of demonstration. A responsible production
		# implementation would need additional scrutiny to keep people
		# from doing naughty things.
		if source = RTS_BGP && net.len <= 48 then {
			accept;
		}
{% endif %}
                reject;
        };
}

template bgp ibgp6 {
	# A protocol template for iBGP sessions between border routers at each site.

        # Reasonable logging.
        debug { states, routes, interfaces, events, packets };

	multihop 2;

{% if network.bird.bgp is defined and network.bird.bgp.allow_myas|default(False) %}
        # Allow the local AS to appear 10 times in the ASpath. This is a hack
        # to simply allow us to see opposite site prefixes via eBGP, without
        # iBGP sessions.
	# NOTE: I usually only set this to 1 in production. However, there is a
	# corner-case in the demo that can cause this to break (AS
	# pre-pending), so I opted for a hack.
        allow local as 10;
{% endif %}

	# Default: 240. Set lower for demonstration expediency.
        hold time {{ bgp_hold_time|default('240') }};

	# Send all routes learnt via BGP
	import filter {
		accept;
	};
	export filter {
		if source != RTS_BGP then {
			# Filter debugging.
			#print "DEBUG EXPORT: ", net, " source is ", source, ", not RTS_BGP.";
			reject;
		}
		# Filter debugging.
		#print "DEBUG EXPORT: ACCEPTING ", net, ", proto: ", proto, ", source: ", source, ", from: ", from, ", gw: ", gw, ", preference: ", preference, ", metric: ", igp_metric;
		accept;
	};
}
