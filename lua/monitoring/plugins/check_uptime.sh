#!/bin/bash
#
#      Plugin for checking system uptime
#      You have to pass one argument: critical threshold
#
#      Michal Semeniuk, 2012
#      michalsemeniuk@gazeta.pl
#


if [ "$1" == "" ]
then
 echo "Error!"
 echo "Usage: check_uptime CRITICAL_THRESHOLD"
 exit 3
fi

uptime=`cat /proc/uptime | awk '{ print $1 }' | awk -F"." '{ print $1 }'`

if [ $uptime -lt $1 ]
then
 echo "CRITICAL - System uptime $uptime s"
 exit 2
else
 echo "OK - System uptime $uptime s"
 exit 0
fi

exit 3