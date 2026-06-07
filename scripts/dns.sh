#!/bin/bash
INTERFACE="wlp0s20f3"
NEXTDNS="45.90.28.0#e5d374.dns.nextdns.io"
MYID="e5d374" # Using your ID for the check

# Check if the current DNS for that interface contains your ID
# -i makes it case-insensitive
IFACE_STATUS=$(resolvectl dns $INTERFACE)

if echo "$IFACE_STATUS" | grep -qi "$MYID"; then
  echo "Switching to Default (Cloudflare)..."
  sudo resolvectl dns $INTERFACE 1.1.1.1
  sudo resolvectl dnsovertls $INTERFACE no
  sudo resolvectl domain $INTERFACE ""
else
  echo "Switching to NextDNS..."
  sudo resolvectl dns $INTERFACE $NEXTDNS
  sudo resolvectl dnsovertls $INTERFACE yes
  sudo resolvectl domain $INTERFACE "~."
fi

# Verification output
echo "--------------------------------"
resolvectl status $INTERFACE | grep "DNS Servers"
