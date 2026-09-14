#!/bin/bash
# Keep selected public domains off the Atmos ZTNA tunnel.
#
# atmosd claims the "~." routing domain on the atmos link, so systemd-resolved
# sends every lookup to 100.65.0.2 at roughly 1s per query, against ~60ms on the
# uplink. It buys nothing: atmos answers internal names (pkgs.devel.redhat.com,
# brewweb.engineering.redhat.com, download.eng.bos.redhat.com) with NXDOMAIN
# just like a public resolver does -- those need the Red Hat VPN -- and returns
# ordinary public addresses for everything else.
#
# Clearing "~." off the atmos link does not work: atmosd re-asserts it within
# seconds, writing to the resolved bus directly rather than through
# NetworkManager, so no dispatcher event fires and nothing can react. Claim
# longer routing domains on the uplink instead. Those win by longest-suffix
# match and sit on a link atmosd never touches.
#
# CNAME targets need their own entry: chasing a CNAME is a fresh lookup, routed
# on the target name. api.dev.testing-farm.io is a CNAME into
# compute.amazonaws.com, so without that second domain only the apex stays off
# atmos and the address still comes back over the tunnel.

set -euo pipefail

action=${2-}

# The events that move the default route or reset link DNS. NordVPN and the Red
# Hat VPN are vpn-type connections, so they raise vpn-up rather than a plain up.
case $action in
	up | down | vpn-up | vpn-down | reapply | dns-change | dhcp4-change | dhcp6-change | connectivity-change) ;;
	*) exit 0 ;;
esac

# Test sysfs, not "resolvectl status atmos" -- that exits 0 even for a missing
# device, which would have us claim domains with nothing to claim them from.
[ -e /sys/class/net/atmos ] || exit 0

# Whatever carries the default route: the local uplink normally, another VPN
# when one is connected. Never atmos itself. Check both families, since an
# IPv6-only network has no v4 default route at all.
uplink=
while read -r dev; do
	[ "$dev" = atmos ] || { uplink=$dev; break; }
done < <({ ip -4 route show default; ip -6 route show default; } |
	sed -n 's/.* dev \([^ ]*\).*/\1/p')
[ -n "$uplink" ] || exit 0

# Every domain this script may add, so a rebuild below drops the ones that no
# longer apply instead of leaving them stranded on the link.
managed='~testing-farm.io ~compute.amazonaws.com ~redhat.com'
wanted='~testing-farm.io ~compute.amazonaws.com'

# redhat.com only while the Red Hat VPN is absent. Its link carries redhat.com
# as a search domain, which matches the same two labels ours would: resolved
# scores that a tie, queries both scopes, and takes whichever answers first --
# so internal names would intermittently get NXDOMAIN from a public resolver.
claimed=false
while read -r line; do
	case $line in
		"Link "*"($uplink):"*) continue ;;
	esac
	case "$line " in
		*" redhat.com "* | *" ~redhat.com "*) claimed=true ;;
	esac
done < <(resolvectl domain)
$claimed || wanted="$wanted ~redhat.com"

# pipefail matters here: without it a failing resolvectl leaves $current empty
# and the apply below silently drops the DHCP search domain along with it.
current=$(resolvectl domain "$uplink" | sed 's/^Link [0-9]* ([^)]*):[[:space:]]*//')

keep=
for d in $current; do
	case " $managed " in
		*" $d "*) continue ;;
	esac
	keep="$keep $d"
done

# shellcheck disable=SC2086 # word splitting is the point
resolvectl domain "$uplink" $keep $wanted
