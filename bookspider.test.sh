#!/bin/bash

timetotal=30	 # number of seconds to take.

if [ "$1" == "--listplugins" ]; then
	# Print a fake list of plugins
	echo "test1"
	echo "test2"
	echo "test3"
	exit
fi

FILE=/tmp/tempfile.txt

if [ "$1" == "-v" ]; then
	shift
fi

if [ "$1" == "-p" ]; then
	shift
	PLUGIN=$1
	shift
fi

if [ "$1" == "-f" ]; then
	shift
	FILE=$1
	shift
fi

cat /dev/null > $FILE	 #Dangersome?

# Pretend to take a long time to do something.
curtime=1
while [ $curtime -le $timetotal ]; do
	/bin/echo "Waiting...$curtime/$timetotal" >&2
	/bin/echo "Waiting (write) ...$curtime/$timetotal" >> $FILE
	/bin/sleep 1
	let curtime=curtime+1
done
