#!/bin/bash
# clean.sh

killall crfe
killall mlogger
killall mserver
killall mhttpd
killall malibu_fe
killall msysmon
killall msysmon-nvidia

#soemwhat rash...
killall xterm
