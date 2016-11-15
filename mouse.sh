#!/bin/bash

case ${1} in
	right )
		xdotool mousemove_relative 20 0
	;;
	left )
		xdotool mousemove_relative -- -20 0
	;;
	up )
		xdotool mousemove_relative 0 -20
	;;
	down )
		xdotool mousemove_relative 0 20
	;;
	jright )
		xdotool mousemove_relative 200 0
	;;
	jleft )
		xdotool mousemove_relative -- -200 0
	;;
	jup )
		xdotool mousemove_relative 0 -200
	;;
	jdown )
		xdotool mousemove_relative 0 200
	;;
	riup )
		xdotool mousemove_relative 20 -20
	;;
	rido )
		xdotool mousemove_relative 20 20
	;;
	leup )
		xdotool mousemove_relative -- -20 -20
	;;
	ledo )
		xdotool mousemove_relative -- -20 20
	;;
	lclick )
		xdotool click 1
	;;
	rclick )
		xdotool click 3
	;;
	wdown )
		xdotool click --repeat 5 4
	;;
	wup )
		xdotool click --repeat 5 5
	;;
esac
