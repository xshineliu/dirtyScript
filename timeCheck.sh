#!/usr/bin/env bash

BASE_PATH="/MYTOOL"
LIB_PATH="${BASE_PATH}/lib"


if [ ! -e /MYTOOL/bin/nc ]; then
    NC=nc
else
    NC=/MYTOOL/bin/nc
fi

source /etc/profile
export LC_ALL=C
export LANG=C


print_info() {
    echo "I: fix: $1"
}

print_error() {
    echo "E: fix: $1" >&2
    exit 1
}

fix_bmc_time() {

    ### recommended run every 10 seconds
    ### Skip VMs
    if [ $(systemd-detect-virt)"XXX" != "noneXXX" ]; then
	    exit 0;
    fi

    ntptime=$(${LIB_PATH}/firmware/bin/ntptool pool.ntp.org)
    if [ $? -eq 0 ]; then
        current_time=$(TZ=UTC date +%s)
        hwtime=$(hwclock --debug -r -u --noadjfile | grep "seconds since 1969"  | awk '{print $8}')
        diff=$((current_time - ntptime))
        if [[ ${diff} -gt 10 ]] || [[ ${diff} -lt -10 ]]; then
            echo "OS TIME ERROR: OS [ $(date -d@${current_time}) ], NTP [ $(date -d@${ntptime}) ]" |  $NC -u -q 0 -w 10 $MYLOGSERVER 27001
        fi

        diff=$((hwtime - ntptime))
        if [[ ${diff} -gt 10 ]] || [[ ${diff} -lt -10 ]]; then
            echo "OS TIME ERROR: HWCLOCK [ $(date -d@${hwtime}) ], NTP [ $(date -d@${ntptime}) ]" |  $NC -u -q 0 -w 10 $MYLOGSERVER 27001
        fi
    fi

    ### ipmi device not proper loaded
    if [ ! -e /dev/ipmi0 ]; then
	    exit 0;
    fi

    current_time=$(TZ=UTC date +%s)
    bmc_time=$(TZ=UTC date -d "$("${LIB_PATH}/firmware/bin/ipmitool" sel time get)" +%s)

    if [ $? -ne 0 ]; then
        echo "BUGGY BMC: sel time get command return error" | $NC -u -q 0 -w 10 $MYLOGSERVER $PORT
        exit 0;
    fi

    diff=$((current_time - bmc_time))
    if [[ ${diff} -gt 5 ]] || [[ ${diff} -lt -5 ]]; then
        print_info "bmc time is not ok, correcting it"
		echo "BMC TIME ERROR: OS [ $(date -d@${current_time}) ], BMC [ $(date -d@${bmc_time}) ]" |  $NC -u -q 0 -w 10 $MYLOGSERVER 27001
        ret=$("${LIB_PATH}/firmware/bin/ipmitool" sel time set "$(TZ=UTC date +"%m/%d/%Y %H:%M:%S")")
		current_time=$(TZ=UTC date +%s)
		bmc_time=$(TZ=UTC date -d"${ret}" +%s)
		diff=$((bmc_time - current_time))
		if [[ ${diff} -gt 3595 ]] || [[ ${diff} -lt -3595 ]]; then
			echo "BUGGY BMC with TZ FIX ${diff}: $(cat /sys/devices/virtual/dmi/id/board_vendor /sys/devices/virtual/dmi/id/product_name | xargs echo)" |  $NC -u -q 0 -w 10 $MYLOGSERVER 27001
        	"${LIB_PATH}/firmware/bin/ipmitool" sel time set "$(TZ=UTC date +"%m/%d/%Y %H:%M:%S" -d@$((current_time - ${diff})))" > /dev/null
		fi
    fi
}

for i in "$@"; do
  case "${i}" in
    bmc_time       ) fix_bmc_time;;
    *              ) print_error "invalid argument: ${i}";;
  esac
done
