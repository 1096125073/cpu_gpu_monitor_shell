#!/bin/bash
# shell script name
prog="$0"
# default top interval
interval=1
# log filename
outfile=""
# default display lines
n=10
# get window size
s=(`stty size`)
window_row=${s[0]}
window_col=${s[1]}
# hlep funtion 
function help {
	echo "this script will monitor the resource usage of triton server."
	echo "Usage: $prog [-hoin] prog"
	echo "	-h			show help message."
	echo "	-o file			save log to file,the filename is option."
	echo "	-i seconds		set the recording interval in seconds,default 1."
	echo "	-n num			scroll to display n latest logs,default 10."
	exit 1
}

# parse parameters
while getopts "ho:i:n:" opt
do
	case $opt in 
		h)
			help;;
		o)
			outfile="$OPTARG";;
		i)	
			interval="$OPTARG";;
		n)	
			n="$OPTARG";;
		?)
			help;;
	esac
done

if [ $OPTIND -ne $# ];then
	help
fi
# get the last parameter, target program name or pid
prog=${@: -1}

# check if the program is exit
function check_status {
	if [ -z "`top -n1 | grep $prog`" ];then
    	echo -e "\033[31m$prog is not running.exit now \033[0m"
    	exit 1
	fi
}
# remove control char and replace multiple space to one,just for top
function strip_control_char {
	if [ $# -ne 1 ];then
		echo "function strip_control_char need one parameter."
		exit 1
	fi
	echo $1 | sed  's/[\t ]\+/,/g' | tr -cd '0-9a-zA-Z,:\.\n%' | sed 's/.*m,//' | sed 's/,/ /g' 
}

# print header
function print_header {
	echo -en "\033[2J\033[0;0H"
	echo -e "\033[1;35mthis script will monitor the cpu and gpu usage,just provide program name or pid. \033[0m"
	echo -e "\033[1;31mlog file: $outfile. \033[0m"
	echo -e 'Time\t\t\tHost Memory(-)\tCPU(%)\tGPU Memory(M)\tGPU(%)'
}
# when window size change,rewrite the whole window
function monitor_window_size_change {
	ts=(`stty size`)
	row=${ts[0]}
	col=${ts[1]}
	if [ $window_row -ne $row -o $window_col -ne $col ];then
		print_header
		window_row=$row
		window_col=$col	
	fi

}
# get default log file
if [ -z "$outfile" ];then
	log_dir="status"
	if ! [ -d "$log_dir" ];then
    	mkdir $log_dir
	fi
	outfile="$log_dir/`date +"%Y-%m-%d_%H:%M:%S"`""_status.log"
fi

# check logfile create permission
touch $outfile 2>&1 1>/dev/zero
if [ $? -ne 0 ];then
       echo -e "\033[1;31m$outfile create failed, please check permission.\033[0m"
       exit 1
fi

check_status
print_header

n=$[ n + 1 ] #skip first row in log file

# get %CPU and RES column index

header="`top -n1 | grep COMMAND`"
str=$(strip_control_char "$header")
cpu_utilization_index=`echo "$str" | awk 'BEGIN{n=0}{for(i=0;i<NF;i++){if($i != "%CPU"){n++}else{break}} } END{print n}'`
cpu_utilization_index=$[ $cpu_utilization_index ]
cpu_memory_index=`echo $str | awk 'BEGIN{n=0}{for(i=0;i<NF;i++){if($i != "RES"){n++}else{break}} } END{print n}'`
cpu_memory_index=$[ $cpu_memory_index  ]
echo -e 'Time\t\t\tHost Memory(-)\tCPU(%)\tGPU Memory(M)\tGPU(%)' > $outfile
while true
do
    check_status
    monitor_window_size_change
    time=`date +"%Y-%m-%d %H:%M:%S"`
    nvi_memory=$(nvidia-smi | grep -m1 ${prog} | awk '{print $8}')
    nvi_utilization=$(nvidia-smi -q -d "Utilization" | grep -m1 Gpu | awk '{print $3}')
    nvi_memory=${nvi_memory/MiB/}
    if [ -z "${nvi_memory}" ];then
	nvi_memory=`nvidia-smi -q -d MEMORY | grep -m1 "Used" | awk '{print $3}'`
    fi
    cpu_info=`top -n 1| grep -m1 ${prog}`
    cpu_status=$(strip_control_char "$cpu_info")
    cpu_data=(`echo $cpu_status | awk -v a=$cpu_memory_index -v b=$cpu_utilization_index '{print $a,$b}'`)
    cpu_memory=${cpu_data[0]}
    cpu_utilization=${cpu_data[1]}
    var="${time}\t${cpu_memory}\t\t${cpu_utilization}\t${nvi_memory}\t\t${nvi_utilization}"
    echo -e $var >>$outfile
    sleep $interval
    echo -en "\033[4;0H\033[K"
    echo "`tail -n $n $outfile | awk '{if(NR!=1){print $0}}'`"
done
