find /var/run/sensorlog/ -name "*.log" -mmin +60 -mmin -1500 | xargs ls -ltr | awk '{print $9, $6, $7, $8}' | sort -n | awk -F\/ 'BEGIN{i=0}; {print i++, $6}'

for i in `cat /root/333.txt`; do echo -ne $i" "; w3m -dump  http://10.1.1.1/info/lastdown.php?srv=$i; done | grep 10 | awk '{print $1, $2, $3, $5, $6}'

for i in $(find /var/run/topinfo/ -name "*.log" -mmin +60 -mmin -43260 | sort -n); do echo -ne $i" "; grep qemu $i > /dev/null; if [ $? -eq 0 ]; then echo -ne "IAAS "; else  echo -ne "---- "; fi; echo $(stat $i | grep Mod | awk '{print $2, $3}' | cut -b -19); done

########################################

IFS=. read ip1 ip2 ip3 ip4 <<< "$1"
#echo $ip1 $ip2 $ip3 $ip4
path=$(printf "/var/run/sensorlog/%03d_%03d_%03d_000/%03d_%03d_%03d_%03d.log" $ip1 $ip2 $ip3 $ip1 $ip2 $ip3 $ip4)

if [ -e $path ]; then
	stat $path | grep Mod | awk '{print $2, $3}' | cut -b -19
else
	echo "NA"
fi

#######################################


while [ 1 -gt 0 ]; do
	val=$(expr $(hwclock --debug -r -u --noadjfile | grep "seconds since 1969" | awk '{print $8}') - $(date +%s))
	lable=$(date +%Y%m%d_%H%M%S)
	echo $lable $val
	sleep 10
done


#######################################


datestr=$( date +"%Y%m%d" -d @$(($(date +%s) - 86400)) )
datestr2=$( date +"%Y%m%d" -d @$(($(date +%s) - 172800)) )
datestr3=$( date +"%Y%m%d" -d @$(($(date +%s) - 259200)) )



#######################################

#/bin/bash

MAXKEEP=30
PREFIX=/var/log/sar
TZOFF=8
interval=10

mkdir -p $PREFIX

loop() {

	ts=$(TZ='Asia/Shanghai' date +%Y%m%d)
	ts_last_day=$(TZ='Asia/Shanghai' date +%Y%m%d -d @$(( $(date +%s) - 86400)) )
	ts_to_del=$(TZ='Asia/Shanghai' date +%Y%m%d -d @$(( $(date +%s) - $((86400 * ${MAXKEEP} )) )) )
	FILENAME=${PREFIX}/sar.${ts}.log
	FILENAME_LASTDAY=${PREFIX}/sar.${ts_last_day}.log
	FILE_TO_DEL=${PREFIX}/sar.${ts_to_del}.log.gz


	if [[ -e ${FILENAME_LASTDAY} ]]; then
		if [[ ! -e ${FILENAME_LASTDAY}.gz ]]; then
			gzip ${FILENAME_LASTDAY} &
		fi
	fi

	if [[ -e ${FILE_TO_DEL} ]]; then
		rm -f ${FILE_TO_DEL} &
	fi



	now=$(date +%s)
	remain_sec=$(( 86400 - $(( $((now + $((TZOFF * 3600)))) % 86400)) ))

	sar -A ${interval} $(( $(($remain_sec + $interval)) % $interval)) >> ${FILENAME}

}


while [ 1 -gt 0 ]; do
	loop
done


#######################################

#!/bin/bash

function reset {
	/root/shine/ipmitool-1.8.18/src/ipmitool -I lanplus -H $1 -U XXXX -P $2 power reset
	return 0;
}

reset 10.99.37.20 XXX
reset 10.99.34.104 XXX

exit 0


#######################################


