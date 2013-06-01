#!/bin/bash

iface="$(ps ax | sed '/[0-9]\s*dhcpcd/!d;s/.*\s\([a-z0-9]*\)$/\1/')"
case "$script_type" in
	"up")
		for i in {0..10}
		do
			read bla option value <<<$(eval echo \$foreign_option_${i})
			case ${option} in
				"DNS")
					echo "nameserver ${value}" >> /etc/resolv.conf.head
				;;
				"DOMAIN")
					echo "domain ${value}" >> /etc/resolv.conf.head
				;;
			esac
		done
		if [ -n "${iface}" ]
		then
			dhcpcd -g "${iface}"
		else
			[ -e /etc/resolv.conf.bkp ] || mv /etc/resolv.conf /etc/resolv.conf.bkp
			cp /etc/resolv.conf.head /etc/resolv.conf
		fi
	;;
	"down")
		rm -f /etc/resolv.conf.head
		[ -z "${iface}" ] && [ -e /etc/resolv.conf.bkp ] && mv /etc/resolv.conf.bkp /etc/resolv.conf
		[ -n "${iface}" ] && dhcpcd -g "${iface}"
	;;
esac

exit 0
