#!/bin/sh
PURPLE='\033[1;35m'
DIM='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

printf "${PURPLE}"
cat << "EOF"
   ____                   _
  / __ \                 | |
 | |  | |_   _  __ _ _ __ | |_ _   _ _ __ ___
 | |  | | | | |/ _` | '_ \| __| | | | '_ ` _ \
 | |__| | |_| | (_| | | | | |_| |_| | | | | | |
  \___\_\\__,_|\__,_|_| |_|\__|\__,_|_| |_| |_|

           C L O U D   P R O V I D E R
EOF
printf "${NC}"
printf "${DIM}"
echo "------------------------------------------------------"
printf "${NC}"
echo " Node:     $(hostname)"
echo " Uptime:   $(uptime -p 2>/dev/null)"
echo " User:     $(whoami)"
printf "${CYAN}"
echo " Support:  discord.gg/ (contact @blaze_gazzer)"
printf "${NC}"
printf "${DIM}"
echo "------------------------------------------------------"
printf "${NC}\n"
