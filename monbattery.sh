#!/bin/bash

[ $EUID -ne 0 ] && echo "This script has to be run as root." >&2 && exit 1

if [ -e /tmp/monbattery.pid ]
then
	if pgrep -F /tmp/monbattery.pid >/dev/null
	then
		echo "The script is already running." >&2
		exit 0
	fi
	rm -f /tmp/monbattery.pid
fi
echo $$ >/tmp/monbattery.pid

energy_full_path="/sys/class/power_supply/BAT1/energy_full"
energy_now_path="/sys/class/power_supply/BAT1/energy_now"
battery_status_path="/sys/class/power_supply/BAT1/status"
warn=20
crit=12
off=10

[ -r "${energy_full_path}" ] || { echo "The path specified for energy_full doesn't exist." && exit 1 ; }
[ -r "${energy_now_path}" ] || { echo "The path specified for energy_now doesn't exist." && exit 1 ; }

while true
do
	sleep 20
	[ "$(<"${battery_status_path}")" == "Discharging" ] || continue
	perc=$(($(<"${energy_now_path}")*100/$(<"${energy_full_path}")))
	if [ ${perc} -lt ${warn} -a ${perc} -gt ${crit} ]
	then
		notify-send -u critical -t 5000 -a monbattery "Battery low" "Hi, your battery is below ${warn}."
	elif [ ${perc} -lt ${crit} -a ${perc} -gt ${off} ]
	then
		notify-send -u critical -t 20000 -a monbattery "Battery critical" "Hey, wake up your battery is below ${crit}."
		mplayer /usr/share/sounds/freedesktop/stereo/power-plug.oga
		mplayer /usr/share/sounds/freedesktop/stereo/power-unplug.oga
		mplayer /usr/share/sounds/freedesktop/stereo/power-plug.oga
		mplayer /usr/share/sounds/freedesktop/stereo/power-unplug.oga
		mplayer /usr/share/sounds/freedesktop/stereo/power-plug.oga
		mplayer /usr/share/sounds/freedesktop/stereo/power-unplug.oga
	elif [ ${perc} -lt ${off} ]
	then
		notify-send -u critical -t 10000 -a monbattery "Battery empty" "Now your battery is below ${off} I'm shutting down in 10 sec."
	        pauser="$(ps aux | grep pulseaudio | grep -v grep | cut -d' ' -f1)"
	        for user in ${pauser}
	        do
	                sudo -u "${user}" /usr/local/bin/pulse_mixer.sh mute
			sleep 3
			for i in {1..15}
			do
	                	sudo -u "${user}" /usr/local/bin/pulse_mixer.sh down
			done
			sleep 3
			mplayer /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
			for i in {1..15}
			do
	                	sudo -u "${user}" /usr/local/bin/pulse_mixer.sh up
			done
	        done
		sleep 4
		[ "$(<"${battery_status_path}")" == "Discharging" ] && pm-hibernate
	fi
done
