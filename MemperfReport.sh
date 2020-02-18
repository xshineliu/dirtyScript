#!/usr/bin/env bash

BASE_PATH="/TOOLKIT"
LIB_PATH="${BASE_PATH}/lib"

export LC_ALL=C
export LANG=C

### Skip VMs  ###
if [ $(systemd-detect-virt)"XXX" != "noneXXX" ]; then
    echo "VM detected. Comment out the next line, if you really would like to run on VMs"
    exit 0
fi



### do timer checking ###
FIX_ITR=432000
FLOAT_ITR_BASE=86400
EXPECT_TS=9000000000
BOOTUP_RND=300


UPTIME_NOW=$(cat /proc/uptime | awk '{printf "%d", $1}')

if [ ! -e /TOOLKIT/misc ]; then
	mkdir -p /TOOLKIT/misc
fi

MBW_NTS_FILE=/TOOLKIT/misc/mbw_next_ts.txt

if [ -e $MBW_NTS_FILE ]; then
	EXPECT_TS=$(cat $MBW_NTS_FILE)
	if [ $UPTIME_NOW -lt $EXPECT_TS ]; then
		### timer not expired yet
		exit 0;
	fi
fi


### restrict ping
DEST_SRV=MYSERVER
DEST_PORT=20001

### check net work, must before $MBW_NTS_FILE change
ping -c 1 $DEST_SRV
RET=$?
if [ $RET -ne 0 ]; then
	### wait for network ready
	exit 0;
fi


### first setup
if [ ! -e $MBW_NTS_FILE ]; then
	### just bootup
	if [ $UPTIME_NOW -gt 300 ]; then
		### pkg update, or service startup too late, system already run for more than 5min, or file unexpected missing
		FLOAT_TS=$(($(od -An -N2 -i /dev/random) % 86400))
		NEXT_CALL=$((UPTIME_NOW + FLOAT_TS))
    	echo $NEXT_CALL > $MBW_NTS_FILE
    	exit 0;
	fi
fi


### TS checked passed
FLOAT_TS=$(($(od -An -N2 -i /dev/random) % $FLOAT_ITR_BASE))
NEXT_CALL=$((UPTIME_NOW + FIX_ITR + FLOAT_TS))
echo $NEXT_CALL > $MBW_NTS_FILE


NC_EXE=nc
if [ -e /TOOLKIT/bin/nc ]; then
	NC_EXE=/TOOLKIT/bin/nc
fi


EXE="${LIB_PATH}/perf-probe/bin/mbw_ssse3_icc19u3"
MEMCHK_EXE="${LIB_PATH}/perf-probe/bin/getMemoryInfo"
MAX_CORES=6

N=10000000
R=5

export NLCPU=$(lscpu | grep -E "^CPU\(s\)" | awk '{print $2}')
export NCORESPS=$(lscpu | grep -E "^Core\(s\) per socket:" | awk '{print $4}')
export NNUMA=$(lscpu | grep -E "^NUMA node\(s\)" | awk '{print $3}')
export NHT=$(lscpu | grep -E "^Thread\(s\) per core" | awk '{print $4}')
export NSOCKETS=$(lscpu | grep -E "^Socket\(s\)" | awk '{print $2}')

### For those Xeon 8160 or 8260, use more cores
if [ $NCORESPS -gt 12 ]; then
    MAX_CORES=$(($((NCORESPS * 60)) / 100))
fi

if [ $NCORESPS -lt $MAX_CORES ]; then
    export OMP_NUM_THREADS=$NCORESPS
else
    export OMP_NUM_THREADS=$MAX_CORES
fi


if [ $1"XXX" == "minXXX" ]; then
    N=10000000
    R=5
fi

### use more resource when server just boot up
if [ $1"XXX" == "maxXXX" ] || [ $UPTIME_NOW -lt 360 ]; then
    N=80000000
    R=21
    EXE="${LIB_PATH}/perf-probe/bin/mbw_avx2_icc19u3"
    export OMP_NUM_THREADS=$NCORESPS
fi

### 58593 per 10M
PGS=$(( N / 10000 * 60))

lscpu | grep "Model name" | nc -q 0 $DEST_SRV $DEST_PORT
if [ -e /TOOLKIT/arch_mem.txt ]; then
        grep TOOLKIT /TOOLKIT/arch_mem.txt | $NC_EXE -q 0 $DEST_SRV $DEST_PORT
fi

TOOLKIT_VERSION="$(TOOLKIT --version)"

if [ ! -e $MEMCHK_EXE ]; then
	exit 0;
fi

if [ ! -e $EXE ]; then
	exit 0;
fi

### need bash
MEM_AVL=($($MEMCHK_EXE | sort -n | awk '{print $10}' | xargs echo))

###
echo 1000 > /proc/$$/oom_score_adj

for ((i=0; i<${NSOCKETS}; i++)); do
	if [ ${MEM_AVL[$i]} -lt $PGS ]; then
		echo "numactl -N${i} -m${i} $EXE -n $N -r $R ### $(date +%Y%m%d_%H%M%S) ### ${TOOLKIT}" | tee /dev/stderr |  $NC_EXE -q 0 $DEST_SRV $DEST_PORT
		echo "Memory insufficient on node ${i}, estimated free as ${MEM_AVL[$i]} pages, while need $PGS pages" | tee /dev/stderr |  $NC_EXE -q 0 $DEST_SRV $DEST_PORT
		continue;
	fi
    echo "numactl -N${i} -m${i} $EXE -n $N -r $R ### $(date +%Y%m%d_%H%M%S) ### ${TOOLKIT}" | tee /dev/stderr |  $NC_EXE -q 0 $DEST_SRV $DEST_PORT
    numactl -N${i} -m${i} $EXE -n $N -r $R | tee /dev/stderr |  $NC_EXE -q 0 $DEST_SRV $DEST_PORT
    sleep 1
done

exit 0
