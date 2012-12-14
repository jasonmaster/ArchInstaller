#!/bin/bash
#
# DESCRIPTION AND MOTIVATION 
# --------------------------
# Designed for an undervolted laptops with frequency stepping, this script
# swings the system between aggressive and low power use, and also swings
# among the available frequencies.
# 
# The idea is that such exteme use of the system will likely explore corner
# cases where the system might fail.  Hopefully, such testing can curtail the
# time necessary to establish confidence in undervolted systems.
#
# In the background the MPrime program, a prime number search engine, runs in a
# "torture test" mode, in which it tests computations against known results and
# errs out if there's a discrepancy.  Unless it errs out, this script runs
# forever.
# 
# IMPLEMENTATION
# --------------
# The design of this script attempts to address laptops beyond the Thinkpad T42
# for which it was designed.  Many of the function definitions are prepended
# with conditionals that check the system for functionality and either bail out
# or disable features accordingly.
#
# In particular, the nature of what "aggressive" constitutes is defined by a 
# number of "toggle_" functions.  The pre-pended conditional to these functions
# appends the function name to $AGGRESSIVE_TOGGLES if the system appears to
# support the feature.  The toggle_aggression function then calls all the 
# functions in $AGGRESSIVE_TOGGLES.  Look at these "toggle_" functions for 
# examples of how to extend this script for other possible stressing.
#
# EXTERNAL PROGRAMS EMPLOYED
# --------------------------
# Test system integriy (required):  MPrime - http://www.mersenne.org/prime.htm
# Download files:  curl - http://curl.haxx.se
# Read random sectors from CD:  spew (for gorge) - http://spew.berlios.de
# Keep hard disk active:  stress - http://weather.ou.edu/~apw/projects/stress/
#
# EXECUTION
# ---------
# Read this script including all the warnings below, and then make sure all the
# variables in the "Script Globals" section are appropriately set. 
#
# This script uses the mprime binary with the "-t" switch for the MPrime
# "torture test."  This test by default uses all the memory available on the
# system.  However, if you run this system for many hours, your kernel may run
# out of memory, and kill mprime and this script.  To spare yourself this
# problem, use the "NightMemory=" and "DayMemory=" parameters in MPrime's
# local.ini file, a file typically in the same directory as the mprime
# executable (read the MPrime documentation for specifics).  The torture test
# by default uses the greater of these two settings, so just set them both a
# reasonable margin away from the total amount of memory available on your
# system.  On a system with 512MB of RAM, I set these parameters both to 448,
# and had enough memory left over to run my normal set of background processes.
#
# The arguments of this script are "aggression" toggles to disable.  Any
# function below that begins with "toggle_$OPTION" can be disabled by using
# $OPTION as one of the arguments of this script.  Otherwise, all the stressing
# that a system supports are enabled by default.
#
# Because of Warning 3 below, I recommend you run this script as
#
#     stress_test 2>&1 | tee output
#
# so that you have a persistent record of what has happened in case your battery
# drains completely.
#
# Keeping in mind Warning 1.1, run the script for as long as it takes to 
# establish confidence in your system (a few hours, half a day, etc.).
#
# WARNINGS
# --------
# 1) This is a STRESS test, and it is very possible that you may witness some
# very bad behavior.  Some systems might already be on the verge of breaking,
# and this script might push them over the edge, and damage them irreparably.
# Especially since you've probably undervolted your system, please accept the
# inherent risk in running this script.  In fact, I have even seen some
# unexpected behavior on non-undervolted systems running this script.  
#
# 1.1) This is a STRESS test, and it will run your system very hot at times.
# Since you are probably running this test because you've undervolted your
# system, you assumedly care a lot about conserving your battery's charge.
# However, running a system hot and needlessly running through charging cycles
# will tax your battery more than just normal use.  It is very difficult to
# even estimate how much of your battery's life you may throw away running
# this test.  In all likelihood on a battery that's not too old or too new, it
# should be imperceptible, and the security you'll gain after running this test
# will be worth it.  You can alway run this script without the battery
# connected -- just run it with an "ac_via_smapi" argument to disable 
# toggling from the ac to battery power.
#
# 2) Please READ THIS SCRIPT BEFORE RUNNING IT.  It was very much designed for my
# personal system, and although it worked very well for my needs, it relies 
# heavily on a number of external programs for full functionality.  Finding these
# programs isn't so bad (with the exception of MPrime all were available as 
# Debian packages -- spew, gorge, curl, etc.).  As I noted above, I've tried to 
# structure this script such that it can be extended (as opposed to overwritten) 
# to support other functionality.  However, you should also read this script 
# entirely because it's not mature, so it's difficult for me to document all the 
# strange ways in which it might behave under various circumstances.
#
# 3) This script might drain your battery completely.  It has some strong measures
# to prevent that from happening, but I can't make guarantees.   
#
# 4) Be mindful that upon breaking out of this script, your system maybe not be
# in an agreeable state.  There is a bash trap that performs a lot of cleanup 
# if you exit with a Ctrl-C.  But I didn't make the code to revert the CD's speed, 
# the wireless device's original txpower, the display's brightness, etc.  Also, the 
# bash trap isn't perfect, and might fail to restore the system.
#

set -e  # Script designed to bail out on any irregularities.

##############################################
# SCRIPT GLOBALS                             #
#  (may need some adjusting for your system) #
##############################################

MPRIME_BIN="./gimps/mprime" # MPrime binary location (get from
                            #   http://www.mersenne.org/freesoft.htm)
AGGRESSIVE_SLEEP_SEC=90     # Seconds for "agressive" testing interval when 
                            #   testing with a fixed frequency
NONAGGRESSIVE_SLEEP_SEC=120 # Seconds for non-"aggressive" testing interval
                            #   when testing with a fixed frequency
FREQ_CYCLE_SLEEP_SEC=15     # Seconds for each random frequency when testing
                            #   with a fixed aggression
FREQ_CYCLE_NUM=15           # Number of random frequencies to cycle through 
                            #   when testing with a fixed aggression
CAPACITY_LIMIT=50           # Minimum mWh required in battery before the script
                            #   takes time out to recharge the battery
SECONDS_TO_CHARGE=300       # Seconds to charge is $CAPACITY_LIMIT is reached
WIFI_DEVICE=eth1            # Set to garbage if you don't want to use wifi 
MAX_TXPOWER=20              # Tx power (dB) used for wifi device in aggressive
                            #   mode (off in non-aggressive mode)
CDROM_DEV_FILE=/dev/hdc     # Set to garbage if you don't want to use the CD-ROM
MAX_CD_SPEED=24             # Speed of CD in aggressive mode (off in
                            #   non-aggressive mode)

# Some services need to be stopped to prevent a conflict with
# aggressive/non-aggressive mode settings.  These services are restarted in
# reverse order upon the script's exit.  You can customize the path to these
# scripts here if your flavor of GNU doesn't use /etc/init.d/.
#
SERVICES_TO_STOP="tpsmapi powernowd acpid sleepd laptop-mode"
PATH_TO_SERVICES_SCRIPTS="/etc/init.d"

# Some info that should be in SysFS or ProcFS.
#
SYS_CPU_DIR=/sys/devices/system/cpu/cpu0/cpufreq
FREQS="$(cat $SYS_CPU_DIR/scaling_available_frequencies)"
FREQS_ARRAY=($FREQS)
SYS_TPSMAPI_BAT_DIR=/sys/devices/platform/smapi/BAT0
IBM_ACPI_BRIGHTNESS_FILE=/proc/acpi/ibm/brightness
RF_KILL_FILE=/sys/class/net/$WIFI_DEVICE/device/rf_kill

############
# BINARIES #
############
#
# Establishes paths for all binaries to make it easier for functions to test if
# they are executable with 'test -x "$BINARY_BIN"'.  
#
{
  CURL_BIN=$(which curl)
  GORGE_BIN=$(which gorge)
  STRESS_BIN=$(which stress)
  IWCONFIG_BIN=$(which iwconfig)
  IFUP_BIN=$(which ifup)
  IFDOWN_BIN=$(which ifdown)
  EJECT_BIN=$(which eject)
  CPUFREQSET_BIN=$(which cpufreq-set)
  KILLALL_BIN=$(which killall)
  RENICE_BIN=$(which renice)
} || true

#############
# FUNCTIONS #
############# 

# clean_up()
#
# Kills mprime background job and starts services that were stopped at the
# beginning of the scripts execution.
#
if [ ! -x "$KILLALL_BIN" ]
  then echo "Sorry, this script uses killall" ; exit 1
fi
for service in $SERVICES_TO_STOP ; do
  if [ ! -x "$PATH_TO_SERVICES_SCRIPTS/$service" ]
    then echo "$PATH_TO_SERVICES_SCRIPTS/$service can't be called." ; exit 1
  fi
done
clean_up()
{
  $KILLALL_BIN -q mprime || true
  if [ "$AGGRESSIVE" = "true" ] ; then toggle_aggression ; fi
  local SERVICES_TO_START=""
  for service in $SERVICES_TO_STOP
    do SERVICES_TO_START="$service $SERVICES_TO_START"
  done
  for service in $SERVICES_TO_START
    do $PATH_TO_SERVICES_SCRIPTS/$service start
  done
}
trap "echo 'cleaning up...' ; clean_up" SIGINT SIGTERM SIGHUP

# do_sleep()
#
# Before starting a testing interval, checks in the battery is low, and charges the
# battery if necessary.  After the testing interval, the running status of the 
# mprime background job is verified. 
#
# TODO: I've not addressed multiple batteries, APM, or ACPI.
#
if [ ! -r "$SYS_TPSMAPI_BAT_DIR/remaining_capacity" ] 
  then 
    echo -n "WARNING: Thinkpad SMAPI SysFS interface not " > /dev/stderr
    echo "available to detect if battery" > /dev/stderr
    echo -n "         level too low.  This script could drain " > /dev/stderr
    echo "all of your battery." > /dev/stderr
fi
do_sleep()
{
  if [ -r "$SYS_TPSMAPI_BAT_DIR/remaining_capacity" ] ; then
    local REMAINING_CAPACITY
    while REMAINING_CAPACITY=$(cat $SYS_TPSMAPI_BAT_DIR/remaining_capacity \
                                2> /dev/std) \
      && REMAINING_CAPACITY=${REMAINING_CAPACITY%% *} \
      && [ "$REMAINING_CAPACITY" ] \
      && [ "$REMAINING_CAPACITY" -lt "$CAPACITY_LIMIT" ] ; do
        echo ; echo -n "Battery is too low to continue, " 
        echo "taking a break to charge up."
        OLD_AGGRESSIVE="$AGGRESSIVE"
        if [ "AGGRESSIVE" = "true" ] ; then toggle_aggression ; fi
        sleep $SECONDS_TO_CHARGE 
        if [ ! "$OLD_AGGRESSIVE" = "$AGGRESSIVE" ] ; then toggle_aggression ; fi
    done
  fi
  sleep $1
  if kill -0 $MPRIME_PID 2> /dev/null 
    then return 0
    else 
      echo ; echo "mprime bailed out here!"
      clean_up
      exit 1
  fi
}

# set_frequency()
#
# Changes the frequency of the processor to $1.
#
# TODO: Perhaps there should be other ways to change the frequency another way.
#       I found cpufreq-set convenient because it handles both ProcFS _and_
#       SysFS.
#
if [ ! -x "$CPUFREQSET_BIN" ] ; then
  echo "Sorry, the set_frequency() function needs to be updated" > /dev/stderr
  echo "    to change frequencies without cpufreq-set." > /dev/stderr
  exit 1
fi
set_frequency()
{
  $CPUFREQSET_BIN -f $1
}

# toggle_ac_via_smapi()
#
# If the system is an Thinkpad with the tp_smapi kernel module set up, the 
# ac power is cut in an aggressive mode and returned in the non-agressive mode. 
#
if [ -w "$SYS_TPSMAPI_BAT_DIR/force_discharge" \
  -a -w "$SYS_TPSMAPI_BAT_DIR/inhibit_charge_minutes" ]
    then AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_ac_via_smapi"
fi
toggle_ac_via_smapi()
{
  if [ "$AGGRESSIVE" = "true" ]
    then
      echo 0 > $SYS_TPSMAPI_BAT_DIR/force_discharge 
      echo 0 > $SYS_TPSMAPI_BAT_DIR/inhibit_charge_minutes
    else 
      echo 1 > $SYS_TPSMAPI_BAT_DIR/force_discharge 
      echo 5 > $SYS_TPSMAPI_BAT_DIR/inhibit_charge_minutes
  fi
}

# toggle_ibm_acpi_brightness()
#
# If the Thinkpad ibm_acpi kernel module is set up, the brightness of screen
# is set to the brightest setting in an agressive mode and the dimmest setting
# otherwise.
#
if [ -w "$IBM_ACPI_BRIGHTNESS_FILE" ]
    then AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_ibm_acpi_brightness"
fi
toggle_ibm_acpi_brightness()
{
  if [ "$AGGRESSIVE" = "true" ]
    then echo level 0 > $IBM_ACPI_BRIGHTNESS_FILE
    else echo level 7 > $IBM_ACPI_BRIGHTNESS_FILE
  fi
}

# toggle_intel_wireless()
#
# Turns the wireless device on in power-hogging mode when aggressive, and
# turns the device off otherwise.
#
# NOTE: Designed for the Intel 2200BG open source driver, and may not be 
#   compatible with much else.  
#
if [ -w "$RF_KILL_FILE" -a -x "$PKILL_BIN" -a -x "$IFDOWN_BIN" \
  -a -x "$IFUP_BIN" -a -x "$IWCONFIG_BIN" -a "$WIFI_DEVICE" ] \
    && grep "$WIFI_DEVICE" /proc/net/wireless
      then 
        AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_intel_wireless"
        $IWCONFIG_BIN $WIFI_DEVICE txpower $MAX_TXPOWER
        $IWCONFIG_BIN $WIFI_DEVICE power off
fi
toggle_intel_wireless()
{
  if [ "$AGGRESSIVE" = "true" ]
    then echo 1 > $RF_KILL_FILE
    else 
      echo 0 > $RF_KILL_FILE
      $PKILL_BIN ^ifdown$\|^ifup$ || true
      $IFDOWN_BIN $WIFI_DEVICE 2> /dev/null || true
      $IFUP_BIN $WIFI_DEVICE 2> /dev/null
      local NUM_OF_TRIES=0
      while $IWCONFIG_BIN $WIFI_DEVICE | grep unassociated > /dev/null \
          && [ "$NUM_OF_TRIES" -lt 15 ]
        do sleep 3
        NUM_OF_TRIES=$(($NUM_OF_TRIES + 1))
      done
  fi
}

# toggle_gorge()
#
# In an aggressive mode, reads data from the CD-ROM at random offsets using the 
# 'gorge' command (http://spew.berlios.de/).
#
# NOTE: Don't use a DVD, as the speed set by `eject' doesn't affect DVDs.
#
# NOTE: Make sure to use a CD with more than 450MB of data.
#
if [ -x "$GORGE_BIN" -a -x "$KILLALL_BIN" -a -r "$CDROM_DEV_FILE" ]
  then AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_gorge"
fi
toggle_gorge()
{
  if [ "$AGGRESSIVE" = "true" ]
    then $KILLALL_BIN -q $GORGE_BIN || true
    else 
      $GORGE_BIN -r 450M $CDROM_DEV_FILE 2> /dev/null &
      local GORGE_PID=$!
      #
      # My laptop needed a little priority push to get gorge CD reading started
      # in sync with the interval.
      #
      if [ -x "$RENICE_BIN" ]
        then $RENICE_BIN -2 -p $GORGE_PID > /dev/null
      fi
  fi
}

# toggle_stress()
#
# Runs the `stress' program (http://weather.ou.edu/~apw/projects/stress/) in 
# the aggressive mode with settings to issue a large number of write(), 
# unlink(), and sync() events.
#
if [ -x "$STRESS_BIN" -a -x "$KILLALL_BIN" ]
  then AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_stress"
fi
toggle_stress()
{
  if [ "$AGGRESSIVE" = "true" ]
    then $KILLALL_BIN -q $STRESS_BIN || true
    else $STRESS_BIN -q -i 1 -d 1 &
  fi
}

# toggle_curl()
#
# Downloads a file (to drain power through the wireless device) in the
# aggressive mode using `curl'.
#
if [ -x "$CURL_BIN" -a -x "$KILLALL_BIN" ]
  then AGGRESSIVE_TOGGLES="$AGGRESSIVE_TOGGLES toggle_curl"
fi
toggle_curl()
{
  URL_FIRST_HALF="http://cdimage.debian.org/cdimage/weekly-builds/"
  URL_SECOND_HALF="i386/iso-cd/debian-testing-i386-binary-1.iso"
  if [ "$AGGRESSIVE" = "true" ]
    then $KILLALL_BIN -q $CURL_BIN || true
    else $CURL_BIN $URL_FIRST_HALF$URL_SECOND_HALF > /dev/null 2> /dev/null &
  fi
}

# toggle_aggression()
#
# Runs all the "toggle_" functions supported by the system unless specified
# as disabled in the script arguments.
#
for toggle_to_disable in $@ 
  do AGGRESSIVE_TOGGLES=$(echo $AGGRESSIVE_TOGGLES \
                            | sed -e "s/toggle_$toggle_to_disable//")
done
toggle_aggression()
{ 
  for toggle in $AGGRESSIVE_TOGGLES ; do $toggle ; done
  if [ "$AGGRESSIVE" = "true" ]
    then AGGRESSIVE="false"
    else AGGRESSIVE="true"
  fi
}

#########
# SETUP #
#########

# Stopping services that might interfere with the system state this script
# controls (precondition satisfied in definition of clean_up).
#
for service in $SERVICES_TO_STOP
  do /etc/init.d/$service stop
done

# Setting CD to a fast speed 
#
if [ -x "$EJECT_BIN" ] 
  then $EJECT_BIN -x $MAX_CD_SPEED
elif [ -x "$HDPARM_BIN" ]
  then $HDPARM_BIN -E $MAX_CD_SPEED
fi 

# Starting the prime number search
#
if [ ! -x "$MPRIME_BIN" ] ; then 
  echo "mprime program not executable/found." > /dev/stderr
  exit 1
fi  
$MPRIME_BIN -t > mprime_output.txt &
MPRIME_PID=$!

########
# BODY #
########

while true ; do
  for f in $FREQS ; do
    echo "Cycling aggression twice for ${f}kHz: "
    set_frequency $f
    if [ ! "$AGGRESSIVE" = "true" ] ; then toggle_aggression ; fi
    for i in 1 2 ; do
      echo "    high " ; do_sleep $AGGRESSIVE_SLEEP_SEC ; toggle_aggression
      echo "    low " ; do_sleep $NONAGGRESSIVE_SLEEP_SEC ; toggle_aggression
    done
    echo 
    for i in 1 2 ; do
      if [ $i -eq 1 ] 
        then
          if [ ! "$AGGRESSIVE" = "true" ] ; then toggle_aggression ; fi
          echo "Random freqs under high aggression: "
        else
          if [ "$AGGRESSIVE" = "true" ] ; then toggle_aggression ; fi
          echo "Random freqs under low aggression: "
      fi 
      for (( i=1 ; i<=$FREQ_CYCLE_NUM ; i+=1 )) ; do
        FREQ=${FREQS_ARRAY[$(($RANDOM % 6))]}
        echo "    ${FREQ}..."
        set_frequency $FREQ
        do_sleep $FREQ_CYCLE_SLEEP_SEC
      done
      echo
    done
  done
done
