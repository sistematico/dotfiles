#!/usr/bin/env bash
# Collects system stats and prints them as a single JSON object.
set -o pipefail

# ---- CPU usage (delta over 300ms) -------------------------------------------
read -r _ u1 n1 s1 i1 w1 irq1 sirq1 st1 _ < /proc/stat
sleep 0.3
read -r _ u2 n2 s2 i2 w2 irq2 sirq2 st2 _ < /proc/stat
idle1=$((i1 + w1)); idle2=$((i2 + w2))
tot1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1))
tot2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2))
dt=$((tot2 - tot1)); di=$((idle2 - idle1))
cpu=0
[ "$dt" -gt 0 ] && cpu=$(( (100 * (dt - di) + dt / 2) / dt ))

# ---- Memory ------------------------------------------------------------------
mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))
mem_pct=$(( (100 * mem_used + mem_total / 2) / mem_total ))
mem_used_h=$(awk -v k="$mem_used" 'BEGIN{printf "%.1f", k/1048576}')
mem_total_h=$(awk -v k="$mem_total" 'BEGIN{printf "%.1f", k/1048576}')

# ---- Disk (root) ---------------------------------------------------------------
read -r disk_size disk_used disk_pct <<< "$(df -h --output=size,used,pcent / | tail -1)"
disk_pct=${disk_pct%\%}

# ---- Temperature ---------------------------------------------------------------
temp=""
for h in /sys/class/hwmon/hwmon*; do
    name=$(cat "$h/name" 2>/dev/null)
    if [ "$name" = "coretemp" ] || [ "$name" = "k10temp" ] || [ "$name" = "zenpower" ]; then
        t=$(cat "$h"/temp1_input 2>/dev/null)
        [ -n "$t" ] && temp=$((t / 1000)) && break
    fi
done
if [ -z "$temp" ]; then
    t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
    [ -n "$t" ] && temp=$((t / 1000))
fi
: "${temp:=0}"

# ---- Load ---------------------------------------------------------------------
read -r l1 l5 l15 _ < /proc/loadavg
cores=$(nproc)

# ---- Uptime -------------------------------------------------------------------
up=$(awk '{s=int($1); d=int(s/86400); h=int(s%86400/3600); m=int(s%3600/60);
    if (d>0) printf "%dd %dh %dm", d, h, m; else if (h>0) printf "%dh %dm", h, m;
    else printf "%dm", m }' /proc/uptime)

# ---- Top processes (by CPU) -----------------------------------------------------
procs=$(ps -eo pcpu,pmem,comm --sort=-pcpu --no-headers | head -6 |
    awk '{ cpu=$1; mem=$2; name=$3; for (i=4; i<=NF; i++) name = name " " $i;
        gsub(/["\\]/, "", name);
        printf "%s{\"name\":\"%s\",\"cpu\":%.1f,\"mem\":%.1f}", (NR>1 ? "," : ""), name, cpu, mem }')

printf '{"cpu":%d,"mem_pct":%d,"mem_used":"%s","mem_total":"%s","disk_pct":%d,"disk_used":"%s","disk_size":"%s","temp":%d,"load1":"%s","load5":"%s","load15":"%s","cores":%d,"uptime":"%s","procs":[%s]}\n' \
    "$cpu" "$mem_pct" "$mem_used_h" "$mem_total_h" "$disk_pct" "$disk_used" "$disk_size" \
    "$temp" "$l1" "$l5" "$l15" "$cores" "$up" "$procs"
