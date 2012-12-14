#!/bin/bash
# Script downloaded from http://www.openmindedbrain.info
# Quick 'n dirty port to Arch by Martin Wimpress <code@flexion.org>
#
# http://www.linux-phc.org/

#                                   #
# Below just some useful functions  #
#                                   #

# Text Colors:
esc="\033["
tc000="${esc}30m"
tcf00="${esc}31m"
tc0f0="${esc}32m"
tcff0="${esc}33m"
tc00f="${esc}34m"
tcf0f="${esc}35m"
tc0ff="${esc}36m"
tcfff="${esc}37m"
tcRst="${esc}0m"
# Background Colors:
bc000="${esc}40m"
bcf00="${esc}41m"
bc0f0="${esc}42m"
bcff0="${esc}43m"
bc00f="${esc}44m"
bcf0f="${esc}45m"
bc0ff="${esc}46m"
bcfff="${esc}47m"


check () {
s=$?
if [ "$s" = "0" ]; then
 printf "$tc0f0> Success!$tcRst\n"
else
 printf "$tcf00> PhaiL!!!$tcRst\n$tcff0> Smash your head on keyboard to continue.$tcRst\n"
 read -n 1 -s > /dev/null
fi
return $s
}

silent_check () {
s=$?
return $s
}

confirm () {
loop=1
while [ "$loop" = "1" ]; do
 printf "Do you want to continue? [Y/n/?] "
 read -n 1 -s answer
 case "$answer" in
  "Y" | "y" | "" )
   printf "${tc0f0}Yes$tcRst\n"
   loop=0
   return 0
   ;;
  "?" )
   printf "${tc00f}?$tcRst\nIt's really just a ${tc0f0}Yes$tcRst or ${tcf00}No$tcRst >:-[\n"
   ;;
  "N" | "n" )
   printf "${tcf00}No$tcRst\n"
   loop=0
   return 1
   ;;
  * )
   printf "${tcff0}$answer$tcRst\n"
   ;;
 esac
done
}

confirm_section () {
confirm || {
 printf "$tc00f> Skipping entire section.$tcRst\n"
 exit 1
}
}

backup () {
printf "Creating backup ${file}~\n"
sudo cp -a "$file" "${file}~"
check
return $?
}

file_check () {
s=0
if [[ "$create" && ! -f "$file" ]]; then
 create=
 printf "  Create $file\n"
 printf "$content" | sudo tee "$file"
 check || return $?
 s=1
fi
if [[ "$owner" && "`stat -c %U:%G \"$file\"`" != "$owner" ]]; then
 printf "  Change ownsership of $file\n"
 sudo chown "$owner" "$file"
 check || return $?
 s=1
fi
if [[ "$perm" && "`stat -c %a \"$file\"`" != "$perm" ]]; then
 printf "  Change permissions of $file\n"
 sudo chmod "$perm" "$file"
 check || return $?
 s=1
fi
if [ "$s" = "0" ]; then
 printf "${tc00f}> SKIPPED:$tcRst Already applied\n"
fi
return 0
}

pattern_count () {
awk "/$pattern/{n++}; END {print n+0}" "$file"
}
line_count () {
awk "/$line/{n++}; END {print n+0}" "$file"
}

pattern_confirm () {
if [ ! -f "$file" ]; then
 printf "${tcff0}> WARNING:$tcRst Could not find $file\n"
 return 1
fi
if [[ ( "$pattern"  && "`pattern_count`" -gt "0" ) || ( ! "$pattern" && "`line_count`" = "0" ) ]]; then
 printf "${tc00f}> SKIPPED:$tcRst Already applied\n"
 return 1
fi
return 0
}

append () {
printf "Appending to $file\n"
printf "$append" | sudo tee -a "$file" > /dev/null
check
return $?
}

replace () {
printf "Scanning $file\n"
result="`awk \"/$line/{sub(/$search/, \\\"$replace\\\")}; {print}\" \"${file}\"`"
check && {
 printf "Writing $file\n"
 printf "$result" | sudo tee "$file" > /dev/null
}
check
return $?
}

confirm_append () {
pattern_confirm && confirm && append
return $?
}

confirm_replace () {
pattern_confirm && confirm && replace
return $?
}

install_confirm () {
printf "\nInstall: $tc0f0$pkgs$tcRst\n"
#dpkg -l $pkgs > /dev/null 2>&1 && {
# dpkg -l $pkgs | grep -q "^[pu]" || {
#  printf "${tc00f}> SKIPPED:$tcRst Already installed\n"
#  return 0
# }
#}
confirm && sudo pacman -S --noconfirm --needed $pkgs
return $?
}

purge_confirm () {
printf "\nUninstall (purge): $tcf00$pkgs$tcRst\n"
#dpkg -l $pkgs 2> /dev/null | grep -q "^i" > /dev/null || {
# printf "${tc00f}> SKIPPED:$tcRst None installed\n"
# return 0
#}
confirm && sudo pacman -R --noconfirm purge $pkgs
return $?
}

#                                   #
# End of the useful functions       #
#                                   #




#                       #
#                       #
#                       #
# Below the actual code #
#                       #
#                       #
#                       #

above_vids=4
burn_wait=93

printf "\n
This script will optimize your voltages at every speed setting 
by systematically lowering them while stressing the CPU.
Each voltage will be turned down until your system crashes, and the final
setting for that voltage will be $tc0f0$above_vids$tcRst VIDs above that to \"ensure\" stability.

WARNING:
This script will crash your system as many times as there are VIDs to tweak.
You might destroy your hardware, break laws and/or die in vain if you continue.\n\n"
confirm || exit 0

num_cpus=0
cpu0freq=/sys/devices/system/cpu/cpu0/cpufreq
cpusfreq=""
while [ [1] ]; do
 cat /sys/devices/system/cpu/cpu$num_cpus/cpufreq/phc_default_vids > /dev/null 2>&1
 silent_check || break
 cpusfreq+="/sys/devices/system/cpu/cpu$num_cpus/cpufreq "
 let num_cpus++
done

if [ $num_cpus = 0 ]; then
 printf "$tcf00> ERROR:$tcRst No CPU core capable of undervolting found.\n"
 exit 1
fi

printf "$tc0f0>Found $num_cpus CPU cores.$tcRst\n"
if [ $num_cpus -gt 1 ]; then
 printf "Multiple cores found, the script will use the
same voltages for all cores, this means final
setting will be $tc0f0$above_vids$tcRst VIDs above the weakest core.\n"
fi

printf "\nInstall required packages.\nWill use burnMMX (part of cpuburn package) to stress CPU."
pkgs="cpuburn" # cpufrequtils
install_confirm

def_vids=`cat $cpu0freq/phc_default_vids`
c=0
for i in $def_vids; do
 let c++
 def_vids_arr[c]=$i
done

if [ -f phc_tweaked_vids ]; then
 printf "\nLoad VIDs from 'phc_tweaked_vids' file\n"
 cur_vids=`cat phc_tweaked_vids`
else
 printf "\nRead default VIDs.\n"
 cur_vids="$def_vids"
fi

count_phc=`printf "$def_vids" | awk '{print NF}'`
count_tweak=`printf "$cur_vids" | awk '{printf NF}'`

if [ "$count_phc" != "$count_tweak" ]; then
 printf "$tcf00> ERROR:$tcRst Wrong VID count!\n"
 exit 1
fi
let count_phc--
check || {
 printf "$tcf00> ERROR:$tcRst Number of VIDs is zero!\n"
 exit 1
}

if [[ -f phc_tweaked_vids && -f phc_cur_pos ]]; then
 printf "Load position from 'phc_cur_pos'\n"
 cur_pos=`cat phc_cur_pos`
 let ++cur_pos
 check || exit 1
else
 printf "Reset position to 0.\n"
 cur_pos=0
fi

printf "Read available frequencies.\n"
freqs=`cat $cpu0freq/scaling_available_frequencies`

c=0
for i in $freqs; do
 let c++
 freq[c]=$i
done
if [ "$c" != "$count_tweak" ]; then
 printf "$tcf00> ERROR:$tcRst Number of frequencies ($c) and VIDs ($count_tweak) do not match!\n"
 exit 1
fi
check

#printf "$cur_vids" | awk '{for (i=1; i<=NF; i++) print $i}'
c=0
for i in $cur_vids; do
 let c++
 vid[c]=$i
 if [ "$c" -lt "$cur_pos" ]; then
  vids_done="$vids_done$i "
 fi
 if [ "$c" = "$cur_pos" ]; then
  printf "\nLast VID: $i\n"
  if [ "${vid[$c]}" -eq 0 -a $c -eq 1 ]; then
   printf "I don't trust the CPU can work with the first VID at 0.\nI'm ignoring it and replace it with the default VID.\n"
   let vid[c]=$def_vids
   vid_last="${vid[c]} "
  else
   let tmp="${vid[c]}"+$above_vids
   if [ $tmp -gt "${def_vids_arr[$c]}" ]; then
    let more="${def_vids_arr[$c]}"-"${vid[$c]}"
   else
    more=$above_vids
   fi
   let vid[c]+=$more
   if [ "${vid[$c]}" -gt "${vid[$(( $c - 1 ))]}" ]; then
    printf "Replace with VID from previous position.\n"
    let vid[c]=vid[c-1]
   else
    printf "Increase by +$more\n"
   fi
   vid_last="${vid[c]} "
  fi
 fi
 if [ "$(( c - 1 ))" = "$cur_pos" ]; then
  vid_next="$i"
 else if [ "$c" -gt "$cur_pos" ]; then
   vids_rem="$vids_rem $i"
  fi
 fi
done

printf "\nDefault VIDs: $def_vids
Current VIDs: $tc0f0$vids_done$tcf00$vid_last$tcff0$vid_next$tcRst$vids_rem\n"

printf "$vids_done$vid_last$vid_next$vids_rem" > phc_tweaked_vids
printf "$cur_pos" > phc_cur_pos

if [ "$cur_pos" -gt "$count_phc" ]; then
 printf "\nAll VIDs have been tweaked!
Results are in the file 'phc_tweaked_vids' - use with care.\n"
 printf "\nAll done! - Have a nice day.\n"
 exit 0 
fi

if [ "x$vid_last" != "x" ]; then
 if [ "$vid_next" -gt "${vid[$cur_pos]}" ]; then
  printf "\nNext VID higher than last - copying."
  vid[$(( cur_pos + 1 ))]=${vid[$cur_pos]}
 fi
fi
let ++cur_pos

printf "\nSwitch to 'userspace' scaling governor.\n"
for i in $cpusfreq; do
 printf "userspace" | sudo tee $i/scaling_governor > /dev/null
done
check || exit 1

printf "Set frequency to ${freq[$cur_pos]}.\n"
for i in $cpusfreq; do
 printf "${freq[$cur_pos]}" | sudo tee $i/scaling_setspeed > /dev/null
done
check || exit 1

printf "Run burnMMX.\n"
pkill burnMMX
for i in $cpusfreq; do
 burnMMX &
 printf " PID: $!\n"
done

recover () {
 printf "\n\nRecovering CPU.\n"
 pkill burnMMX
 for i in $cpusfreq; do
  printf "$def_vids" | sudo tee $i/phc_vids > /dev/null
  printf "ondemand" | sudo tee $i/scaling_governor > /dev/null
 done
 printf "\nRun this script again to continue the optimization.\n"
}

printf "\n-----\nStart testing.\n"
confirm || {
 recover
 exit 1
}

while [[ 1 ]]; do
 let vid[cur_pos]--
 if [ "${vid[$cur_pos]}" -lt "0" ]; then
  printf "\n\nThe lowest acceptable VID is 0."
  recover
  exit 0
 fi

 printf "\nDefault VIDs: $def_vids
Current VIDs: $tc0f0$vids_done$tc0f0$vid_last$tcf00${vid[$cur_pos]}$tcRst$vids_rem
Testing VID: ${vid[$cur_pos]} ($(( ${vid[$cur_pos]} * 16 + 700)) mV)\n"

 printf "$vids_done$vid_last${vid[$cur_pos]}$vids_rem" > phc_tweaked_vids
 sync

 for i in $cpusfreq; do
  printf "$vids_done$vid_last${vid[$cur_pos]}$vids_rem" | sudo tee $i/phc_vids > /dev/null
 done

 c=0
 while [ $c -lt $burn_wait ]; do
  burnMMX_instances=`ps aux | grep [b]urnMMX | wc -l`
  if [ $burnMMX_instances -ne $num_cpus ]; then
   printf "\nburnMMX instances different than the CPU cores number. (Maybe one crashed)!"
   recover
   exit 0
  else
   printf "."
   if [ $c -eq 30 -o $c -eq 61 ]; then
    printf "\n"
   fi
   sleep 0.5
   let c++
  fi
 done
done
