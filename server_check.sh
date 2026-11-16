#!/bin/bash
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

MEM_W=80;   MEM_C=90
DISK_W=80;  DISK_C=90
INODE_W=80; INODE_C=90
LOAD_W=1.0; LOAD_C=2.0
CPU_W=80;   CPU_C=90
ZOMB_W=1;   ZOMB_C=10

if [ "$(id -u)" -eq 0 ]; then
    LOG=/var/log/server_check/alert.log
else
    LOG=/tmp/server_check/alert.log
fi
mkdir -p "${LOG%/*}" 2>/dev/null

A=0; W=0; C=0

sec() { printf '\n===== %s =====\n' "$1"; }

alert() {
    printf '[ALERT][%-4s][%-6s] %s\n' "$1" "$2" "$3"
    printf '%s [%-4s][%-6s] %s\n' "$(date '+%F %T')" "$1" "$2" "$3" >> "$LOG" 2>/dev/null
    A=$((A + 1))
    if [ "$1" = CRIT ]; then
        C=$((C + 1))
    else
        W=$((W + 1))
    fi
}

chk() {
    if awk -v a="$3" -v c="$5" 'BEGIN{exit !(a+0 >= c+0)}'; then
        alert CRIT "$1" "$2 $3$6 >= $5$6"
    elif awk -v a="$3" -v w="$4" 'BEGIN{exit !(a+0 >= w+0)}'; then
        alert WARN "$1" "$2 $3$6 >= $4$6"
    else
        printf '[ OK ][%-6s] %s %s%s < %s%s\n' "$1" "$2" "$3" "$6" "$4" "$6"
    fi
}

sec "SYSTEM"
echo "Hostname : $(hostname)"
echo "OS       : $(cat /etc/redhat-release 2>/dev/null)"
echo "Kernel   : $(uname -r)"
echo "Time     : $(date '+%F %T')"
echo "Uptime   : $(uptime | sed 's/^ *//')"

sec "MEMORY"
read -r mt mu mp <<< "$(awk '/^MemTotal:/{t=$2}/^MemFree:/{f=$2}/^MemAvailable:/{a=$2}/^Buffers:/{b=$2}/^Cached:/{c=$2}END{if(a=="")a=f+b+c;printf "%.0f %.0f %.1f",t/1024,(t-a)/1024,(t-a)/t*100}' /proc/meminfo)"
free -h
echo "Total:${mt}MB  Used:${mu}MB  UsedPercent:${mp}%"
chk mem "mem_used" "$mp" "$MEM_W" "$MEM_C" "%"

sec "DISK"
while read -r m p d; do
    p=${p%\%}
    printf '%-22s %4s%% %s\n' "$m" "$p" "$d"
    chk disk "$m" "$p" "$DISK_W" "$DISK_C" "%"
done < <(df -PT 2>/dev/null | awk 'NR>1 && $2!~/^(tmpfs|devtmpfs|squashfs|iso9660|autofs)$/{p=$6;sub("%","",p);print $7,p,$1}' | sort -k2 -nr)

sec "CPU"
n=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN)
l1=$(cut -d' ' -f1 /proc/loadavg)
read -r t1 i1 <<< "$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)"
sleep 1
read -r t2 i2 <<< "$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)"
u=$(awk -v t1="$t1" -v i1="$i1" -v t2="$t2" -v i2="$i2" 'BEGIN{d=t2-t1;printf "%.1f",(d>0)?(d-(i2-i1))/d*100:0}')
lp=$(awk -v l="$l1" -v n="$n" 'BEGIN{printf "%.2f", l/n}')
echo "Cores:$n  Load1:$l1  LoadPerCore:$lp  CpuUsed:${u}%"
chk cpu "load_per_core" "$lp" "$LOAD_W" "$LOAD_C" ""
chk cpu "cpu_used" "$u" "$CPU_W" "$CPU_C" "%"
ps -eo pcpu,pmem,comm --sort=-pcpu 2>/dev/null | head -4

sec "INODE"
while read -r m p d; do
    p=${p%\%}
    printf '%-22s %4s%% %s\n' "$m" "$p" "$d"
    chk inode "$m" "$p" "$INODE_W" "$INODE_C" "%"
done < <(df -PiT 2>/dev/null | awk 'NR>1 && $2!~/^(tmpfs|devtmpfs|squashfs|iso9660|autofs)$/{p=$6;sub("%","",p);print $7,p,$1}' | sort -k2 -nr)

sec "ZOMBIE"
z=$(ps -eo stat= 2>/dev/null | awk '$1~/^Z/{n++}END{print n+0}')
echo "ZombieCount:$z"
chk zombie "zombie_proc" "$z" "$ZOMB_W" "$ZOMB_C" ""
[ "$z" -gt 0 ] && ps -eo stat=,pid=,ppid=,comm= 2>/dev/null | awk '$1~/^Z/' | head -5

sec "PORT"
if command -v ss >/dev/null 2>&1; then
    ss -tuln
else
    netstat -tuln 2>/dev/null
fi

sec "SUMMARY"
echo "Alerts:$A  CRIT:$C  WARN:$W"
echo "Log:$LOG"
if [ "$A" -eq 0 ]; then
    echo "RESULT: OK"
    exit 0
fi
if [ "$C" -gt 0 ]; then
    echo "RESULT: CRIT"
    exit 2
fi
echo "RESULT: WARN"
exit 1
