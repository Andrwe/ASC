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
crit=14
off=10

[ -r "${energy_full_path}" ] || { echo "The path specified for energy_full doesn't exist." && exit 1 ; }
[ -r "${energy_now_path}" ] || { echo "The path specified for energy_now doesn't exist." && exit 1 ; }

while true
do
	sleep 20
	[ "$(<"${battery_status_path}")" == "Discharging" ] || continue
	perc=$(($(<"${energy_now_path}")*100/$(<"${energy_full_path}")))
	notifyuser="$(ps aux | grep /usr/lib/notify-osd/notify-osd | cut -d' ' -f1)"
	if [ ${perc} -lt ${warn} -a ${perc} -gt ${crit} ]
	then
		for user in ${notifyuser}
		do
			su "$user" -c "notify-send -u critical -t 5000 -a monbattery \"Battery low\" \"Hi, your battery is below ${warn} (${perc}).\""
		done
	elif [ ${perc} -le ${crit} -a ${perc} -gt ${off} ]
	then
		for user in ${notifyuser}
		do
			su "$user" -c "notify-send -u critical -t 15000 -a monbattery \"Battery critical\" \"Hey, wake up your battery is below ${crit} (${perc}).\""
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-plug.oga" >/dev/null 2>&1
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-unplug.oga" >/dev/null 2>&1
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-plug.oga" >/dev/null 2>&1
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-unplug.oga" >/dev/null 2>&1
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-plug.oga" >/dev/null 2>&1
			su "$user" -c "mplayer -ao pulse /usr/share/sounds/freedesktop/stereo/power-unplug.oga" >/dev/null 2>&1
		done
	elif [ ${perc} -le ${off} ]
	then
		for user in ${notifyuser}
		do
			su "$user" -c "notify-send -u critical -t 10000 -a monbattery \"Battery empty\" \"Now your battery is below ${off} (${perc}) I'm shutting down in 10 sec.\""
	        done
		pauser="$(ps aux | grep pulseaudio | grep -v grep | cut -d' ' -f1)"
	        for user in ${pauser}
	        do
	                su "${user}" -c "/usr/local/bin/pulse_mixer.sh mute"
			sleep 3
	                su "${user}" -c "/usr/local/bin/pulse_mixer.sh mute"
			for i in {1..15}
			do
	                	su "${user}" -c "/usr/local/bin/pulse_mixer.sh down"
			done
			sleep 3
			su "$user" -c "mplayer /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" >/dev/null
			for i in {1..15}
			do
	                	su "${user}" -c "/usr/local/bin/pulse_mixer.sh up"
			done
	        done
		sleep 4
		[ "$(<"${battery_status_path}")" == "Discharging" ] && pm-hibernate
	fi
done
