#!/bin/bash
echo "=====ServerCheckInfo====="
echo "Hostname: $(hostname)"
echo "OSVersion: $(cat /etc/redhat-release)"
echo "CurrentTime: $(date)"
echo "cpuload:$(uptime)"
echo "=====MemoryInfo====="
free -h
echo "=====DiskInfo====="
df -h
echo "=====ListenPort====="
ss -tuln
