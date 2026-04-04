#!/bin/bash
# network.sh - Comprehensive network info for Ironbar (SSID, IP, Bandwidth)

# Get active interface
INTERFACE=$(nmcli -t -f DEVICE,STATE dev | grep ":connected" | head -n 1 | cut -d: -f1)

if [ -z "$INTERFACE" ]; then
    echo "󰖪 Sin red"
    exit 0
fi

# Get IP and CIDR
IP_RAW=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
IP=${IP_RAW%/*}
CIDR=${IP_RAW#*/}

# Get Connection Type, SSID and Signal
TYPE=$(nmcli -t -f DEVICE,TYPE dev | grep "^$INTERFACE:" | cut -d: -f2)
if [ "$TYPE" = "wifi" ]; then
    SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep -i "^[ys]" | cut -d: -f2)
    SIGNAL=$(nmcli -t -f ACTIVE,SIGNAL dev wifi | grep -i "^[ys]" | cut -d: -f2)
    ICON="󰖩"
    EXTRA="$SSID ($SIGNAL%)"
else
    ICON="󰈀"
    EXTRA="Ethernet"
fi

# Simplified Bandwidth (Instantaneous byte-count diff over 1s)
# To get a real rate, we'd need to sample twice, but this might be slow for a bar script.
# We'll use /proc/net/dev for raw bytes.
get_bytes() {
    cat /proc/net/dev | grep "$INTERFACE:" | awk '{print $2, $10}'
}

read -r RX1 TX1 <<< $(get_bytes)
sleep 0.5
read -r RX2 TX2 <<< $(get_bytes)

# Calculate rate (bytes/s) - doubled because we sampled for 0.5s
RX_RATE=$(( (RX2 - RX1) * 2 ))
TX_RATE=$(( (TX2 - TX1) * 2 ))

# Format rate
format_rate() {
    local bytes=$1
    if [ $bytes -gt 1048576 ]; then
        printf "%.1f MB/s" $(echo "scale=1; $bytes / 1048576" | bc)
    elif [ $bytes -gt 1024 ]; then
        printf "%.1f KB/s" $(echo "scale=1; $bytes / 1024" | bc)
    else
        echo "$bytes B/s"
    fi
}

UP=$(format_rate $TX_RATE)
DOWN=$(format_rate $RX_RATE)

# Default format if none provided
FORMAT="$1"
# Expand literal \n for multiline output (useful for tooltips)
FORMAT=$(echo -e "$FORMAT")
if [ -z "$FORMAT" ]; then
    FORMAT="{icon} {ifname}: {ip} | {ssid} ({signal}%) | ↑ {up} ↓ {down}"
fi

# Replace placeholders
OUTPUT="$FORMAT"
OUTPUT="${OUTPUT//\{icon\}/$ICON}"
OUTPUT="${OUTPUT//\{ifname\}/$INTERFACE}"
OUTPUT="${OUTPUT//\{ip\}/$IP}"
OUTPUT="${OUTPUT//\{cidr\}/$CIDR}"
OUTPUT="${OUTPUT//\{ssid\}/$SSID}"
OUTPUT="${OUTPUT//\{signal\}/$SIGNAL}"
OUTPUT="${OUTPUT//\{up\}/$UP}"
OUTPUT="${OUTPUT//\{down\}/$DOWN}"

echo "$OUTPUT"
