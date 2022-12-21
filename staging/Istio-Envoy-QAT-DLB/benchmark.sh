#!/usr/bin/bash

# Copyright (c) Intel Corporation.

# Neither the name of Intel Corporation nor the names of its suppliers
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# No reverse engineering, decompilation, or disassembly of this software
#   is permitted.
#
# DISCLAIMER.  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.


trap ctrl_c INT
_positionals=()
USER="root"
NODE_PASS=
PORT=
RPS=
MAX_RPS=
STEP_RPS=10
loop=true #Do not change, whether the program executes in a loop depends only on the setting of the MAX_RPS value
NH_CPU=
PROTOCOL="http1"
DURATION=30
KILL_DELAY=30
MAR=500
MCS=100
CON=1000
RBS=400
MPR=100
MRPC=7
ETH_DEV=
use_perf=false
use_mpstat=false
CONTAINER_NAME="nighthawk"
CONCURRENCY=auto
NOTE=


die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}


print_help()
{
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s <IP> [-u|--user <arg>] [-P|--pass <arg>] [-p|--port <arg>] [-r|--rps <arg>] [--max-rps <arg>] [--step-rps <arg>] [-N|--nh-cpu <arg>] [--protocol <arg>] [-d|--duration <arg>] [-k|--kill-delay <arg>] [--mar <arg>] [--mcs <arg>] [--con <arg>] [--rbs <arg>] [--mpr <arg>] [--mrpc <arg>] [-c|--container-name <arg>] [-e|--eth-dev <arg>] [--(no-)perf] [--(no-)mpstat] [--note <arg>] [-h|--help]\n' "$0"
	printf '\t%s\n' "<IP>: IP of the server machine."
	printf '\t%s\n' "-u, --user: The user we are connecting to via ssh. (default: 'root')"
	printf '\t%s\n' "-P, --pass: User password for ssh connection. (no default)"
	printf '\t%s\n' "-p, --port: The port on which you connect to the server. (required)"
	printf '\t%s\n' "-r, --rps: Number of requests per second. (required)"
	printf '\t%s\n' "--max-rps: If this parameter is specified, measurements will be performed in a loop, starting from the RPS value specified with --rps and ending with the value specified with --max-rps, with a step equal to --step-rps."
	printf '\t%s\n' "--step-rps: RPS step in the loop. (default: 10)"
	printf '\t%s\n' "-N, --nh-cpu: List or range of threads that Nighthawk will use. (required)"
	printf '\t%s\n' "--protocol: Protocol used. (default: 'http1') (possible values: http1, http2 or https)"
	printf '\t%s\n' "-d, --duration: Nighthawk measurement duration [sec]. (default: 30)"
	printf '\t%s\n' "-k, --kill-delay: Time [sec] after which the Nighthawk process will be killed at the end of the measurement, if it does not kill itself. (default: 30)"
	printf '\t%s\n' "--mar: The maximum allowed number of concurrently active requests. (for HTTP/2 and HTTPS) (default: 500)"
	printf '\t%s\n' "--mcs: Max concurrent streams allowed on one HTTP/2 connection. (for HTTP/2 and HTTPS) (default: 100)"
	printf '\t%s\n' "--con: The maximum allowed number of concurrent connections per event loop. (for HTTP/1) (default: 1000)"
	printf '\t%s\n' "--rbs: Size of the request body to send. NH will send a number of consecutive 'a' characters equal to the number specified here. (default: 400)"
	printf '\t%s\n' "--mpr: Max pending requests. (for HTTPS) (default: 100)"
	printf '\t%s\n' "--mrpc: Max requests per connection. (for HTTPS) (default: 7)"
	printf '\t%s\n' "-c, --container-name: Name of the container with Nighthawk. (default: 'nighthawk')"
	printf '\t%s\n' "-e, --eth-dev: ETH DEV. (no default)"
	printf '\t%s\n' "--perf, --no-perf: Determines whether to use Perf during measurements. If Perf is not on the machine, it will be installed. (off by default)"
	printf '\t%s\n' "--mpstat, --no-mpstat: Determines whether to use mpstat during measurements. If mpstat is not on the machine, it will be installed. (off by default)"
	printf '\t%s\n' "--note: Add a note to be added to the report."
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-u|--user)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				USER="$2"
				shift
				;;
			--user=*)
				USER="${_key##--user=}"
				;;
			-u*)
				USER="${_key##-u}"
				;;
			-P|--pass)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				NODE_PASS="$2"
				shift
				;;
			--pass=*)
				NODE_PASS="${_key##--pass=}"
				;;
			-P*)
				NODE_PASS="${_key##-P}"
				;;
			-p|--port)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				PORT="$2"
				shift
				;;
			--port=*)
				PORT="${_key##--port=}"
				;;
			-p*)
				PORT="${_key##-p}"
				;;
			-r|--rps)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				RPS="$2"
				shift
				;;
			--rps=*)
				RPS="${_key##--rps=}"
				;;
			-r*)
				RPS="${_key##-r}"
				;;
			--max-rps)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				MAX_RPS="$2"
				shift
				;;
			--max-rps=*)
				MAX_RPS="${_key##--max-rps=}"
				;;
			--step-rps)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				STEP_RPS="$2"
				shift
				;;
			--step-rps=*)
				STEP_RPS="${_key##--step-rps=}"
				;;
			-N|--nh-cpu)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				NH_CPU="$2"
				shift
				;;
			--nh-cpu=*)
				NH_CPU="${_key##--nh-cpu=}"
				;;
			-N*)
				NH_CPU="${_key##-N}"
				;;
			--protocol)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				PROTOCOL="$2"
				shift
				;;
			--protocol=*)
				PROTOCOL="${_key##--protocol=}"
				;;
			-d|--duration)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				DURATION="$2"
				shift
				;;
			--duration=*)
				DURATION="${_key##--duration=}"
				;;
			-d*)
				DURATION="${_key##-d}"
				;;
			-k|--kill-delay)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				KILL_DELAY="$2"
				shift
				;;
			--kill-delay=*)
				KILL_DELAY="${_key##--kill-delay=}"
				;;
			-k*)
				KILL_DELAY="${_key##-k}"
				;;
			--mar)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				MAR="$2"
				shift
				;;
			--mar=*)
				MAR="${_key##--mar=}"
				;;
			--mcs)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				MCS="$2"
				shift
				;;
			--mcs=*)
				MCS="${_key##--mcs=}"
				;;
			--con)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				CON="$2"
				shift
				;;
			--con=*)
				CON="${_key##--con=}"
				;;
			--rbs)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				RBS="$2"
				shift
				;;
			--rbs=*)
				RBS="${_key##--rbs=}"
				;;
			--mpr)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				MPR="$2"
				shift
				;;
			--mpr=*)
				MPR="${_key##--mpr=}"
				;;
			--mrpc)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				MRPC="$2"
				shift
				;;
			--mrpc=*)
				MRPC="${_key##--mrpc=}"
				;;
			-c|--container-name)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				CONTAINER_NAME="$2"
				shift
				;;
			--container-name=*)
				CONTAINER_NAME="${_key##--container-name=}"
				;;
			-c*)
				CONTAINER_NAME="${_key##-c}"
				;;
			-e|--eth-dev)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				ETH_DEV="$2"
				shift
				;;
			--eth-dev=*)
				ETH_DEV="${_key##--eth-dev=}"
				;;
			-e*)
				ETH_DEV="${_key##-e}"
				;;
			--no-perf|--perf)
				use_perf=true
				test "${1:0:5}" = "--no-" && use_perf=false
				;;
			--no-mpstat|--mpstat)
				use_mpstat=true
				test "${1:0:5}" = "--no-" && use_mpstat=false
				;;
			--note)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				NOTE="$2"
				shift
				;;
			--note=*)
				NOTE="${_key##--note=}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	local _required_args_string="'IP'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


valid_ip()
{
	if (( $# != 1 )); then
		echo "valid_ip() error: Incorrect number of parameters sent to function."
		exit 1
	fi

    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip) #Without the quotes, because the string under the ip variable is to be split in this case
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


test_ssh_connection() {
	echo
    echo "Testing the ssh connection... Connecting to the $USER user at $NODE_IP"
    if ! sshpass -p "$NODE_PASS" ssh -o ConnectTimeout=30 "$USER"@"$NODE_IP" "echo 'Everything works!'"; then
        echo "Something has gone wrong :("
        exit 1
    fi
	echo
	echo "Downloading the path to the $USER's home folder..."
    if ! SSH_USER_HOME_DIR=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" 'echo $HOME'); then #Specially between single quotes so that the $HOME variable is only resolved on the remote machine side, not the local one
		echo "Failed to get the $USER's home folder."
		exit 1
	fi
	echo "Done!"
}


get_info(){
	echo
	echo "Gathering information on the remote machine..."
	echo
	echo "Getting the list of threads on which ingress is running..."
    if ! INGRESS_CPU=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S cat /var/lib/kubelet/cpu_manager_state | jq -r '.entries[] | select(length == 1 and has(\"istio-proxy\")) | .\"istio-proxy\"' | cut -d'\"' -f 2"); then
		echo "Something went wrong, it was not possible to extract the list of threads on which ingress works. Are you sure there is a cluster set up on the remote machine with the Nighthawk server running?"
		exit 1
	fi

	if ! [[ "$INGRESS_CPU" =~ ^[0-9][0-9,-]*$ ]]; then
		echo "Something went wrong, it was not possible to extract the list of threads on which ingress works. Are you sure that Istio is installed on the cluster?"
		exit 1
	fi

	echo "Getting the list of threads on which nighthawk is running..."
	#cat /var/lib/kubelet/cpu_manager_state | jq -r '[.entries[] | with_entries(if(.key|test("sm-nighthawk")) then ( {key: .key, value: .value } ) else empty end) | flatten[]] | @csv' | tr -d '"'
	#cat /var/lib/kubelet/cpu_manager_state | jq -r '[.entries[] | with_entries(select(.key | match("sm-nighthawk")))[]] | @csv' | tr -d '"'
	#cat /var/lib/kubelet/cpu_manager_state | jq -r '[.entries[] | select(length == 3 and has("sm-nighthawk-server") and has("istio-proxy")) | ."sm-nighthawk-server"] | @csv' | tr -d '"'
    if ! NIGHTHAWK_CPU=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S cat /var/lib/kubelet/cpu_manager_state | jq -r '[.entries[] | with_entries(select(.key | match(\"sm-nighthawk\")))[]] | @csv' | tr -d '\"'"); then
		echo "Something went wrong, it was not possible to extract the list of threads on which nighthawk works. Are you sure there is a cluster set up on the remote machine with the Nighthawk server running?"
		exit 1
	fi

	if ! [[ "$NIGHTHAWK_CPU" =~ ^[0-9][0-9,-]*$ ]]; then
		echo "Something went wrong, it was not possible to extract the list of threads on which nighthawk works. Surely a Nighthawk deployment has been made on the cluster? There must be pods running containers (containers should be named sm-nighthawk-server, pods and deployments can have different names) with Nighthawk."
		exit 1
	fi

	echo "Getting the list of threads on which sidecars are running..."
    if ! SIDECAR_CPU=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S cat /var/lib/kubelet/cpu_manager_state | jq -r '[.entries[] | select(length == 3 and has(\"sm-nighthawk-server\") and has(\"istio-proxy\")) | .\"istio-proxy\"] | @csv' | tr -d '\"'"); then
		echo "Something went wrong, it was not possible to extract the list of threads on which sidecars works. Are you sure there is a cluster set up on the remote machine with the Nighthawk server running?"
		exit 1
	fi

	if ! [[ "$SIDECAR_CPU" =~ ^[0-9][0-9,-]*$ ]]; then
		echo "Something went wrong, it was not possible to extract the list of threads on which sidecars works. Are you sure that Istio is installed on the cluster and have you labeled any namespace?"
		exit 1
	fi

	echo "Getting the amount of memory allocated to istio-ingressgateway..."
    if ! memory_limits=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" sudo -S kubectl describe deploy istio-ingressgateway -n istio-system | grep memory: | head -n1 | awk '{print $2}'); then
		echo "Something went wrong :("
		exit 1
	fi
	if ! memory_requests=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" sudo -S kubectl describe deploy istio-ingressgateway -n istio-system | grep memory: | tail -n1 | awk '{print $2}'); then
		echo "Something went wrong :("
		exit 1
	fi
	memory="$memory_limits/$memory_requests"

	echo "Getting the value of the --concurrency parameter for the istio-proxy container in the istio-ingressgateway deployment..."
	if ! ingress_concurrency=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S kubectl describe deploy istio-ingressgateway -n istio-system | grep concurrency | cut -d'=' -f 2"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the operating system version..."
    if ! OS=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "lsb_release -a 2>>/dev/null | grep Description | cut -d: -f2 | xargs"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the kernel version..."
    if ! kernel_version=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "uname -r"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the k8s interface..."
    if ! k8s_int=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "ip addr | grep --before-context=10 \"$NODE_IP\" | egrep \"^[0-9]+:\" | tail -n1 | cut -d: -f 2 | xargs"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the NIC driver version..."
    if ! NIC_driver=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "ethtool -i \"$k8s_int\" | egrep '^version' | cut -d' ' -f 2"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the NIC firmware version..."
    if ! NIC_firmware=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "ethtool -i \"$k8s_int\" | egrep '^firmware' | cut -d' ' -f 2"); then		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the docker version..."
    if ! docker_version=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S docker version | grep 'Version:' | head -n 1 | cut -d: -f 2 | xargs"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the kubernetes version..."
    if ! kube_version=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" sudo -S kubectl get nodes | awk '{print $5}' | sed -n 2p); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the calico version..."
    if ! calico_version=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" sudo -S calicoctl version | head -n1 | awk '{print $3}'); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the istio version..."
    if ! istio_version=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S kubectl describe pod -A | grep 'Image:' | egrep \"(docker.io/istio/proxyv2)|(registry.fi.intel.com/staging/proxyv2)\" | cut -d: -f 3 | sort | uniq -c | xargs"); then
		echo "Something went wrong :("
		exit 1
	else
		istio_version=$(make_prettier "$istio_version")
	fi

	echo "Checking whether hyper threading is enabled..."
    if ! ht=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/smt/active"); then
		echo "Something went wrong :("
		exit 1
	elif [[ "$ht" == "1" ]]; then
		ht="Enabled"
	else
		ht="Disabled"
	fi

	echo "Checking whether turbo boost is enabled..."
    if ! tb=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/intel_pstate/no_turbo"); then
		echo "Something went wrong :("
		exit 1
	elif [[ "$tb" == "0" ]]; then
		tb="Enabled"
	else
		tb="Disabled"
	fi

	echo "Getting the governor..."
    if ! governor=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c | xargs"); then
		echo "Something went wrong :("
		exit 1
	else
		governor=$(make_prettier "$governor")
	fi

	echo "Getting the max cpu frequency"
    if ! cpu_max_freq=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq | sort | uniq -c | xargs"); then
		echo "Something went wrong :("
		exit 1
	else
		cpu_max_freq=$(make_prettier "$cpu_max_freq")
	fi

	echo "Getting the min cpu frequency"
    if ! cpu_min_freq=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq | sort | uniq -c | xargs"); then
		echo "Something went wrong :("
		exit 1
	else
		cpu_min_freq=$(make_prettier "$cpu_min_freq")
	fi

	echo "Getting the name of processor model..."
    if ! proc_name=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "lscpu | grep 'Model name' | cut -d: -f 2 | xargs"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the number of sockets..."
    if ! n_sockets=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" lscpu | grep 'Socket' | awk '{print $2}'); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the number of cores per socket..."
    if ! cps=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" lscpu | grep 'Core(s) per socket' | awk '{print $4}'); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the stepping..."
    if ! stepping=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" lscpu | grep 'Stepping' | awk '{print $2}'); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting the number of NUMA nodes..."
    if ! n_numa_nodes=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" lscpu | grep 'NUMA node(s)' | awk '{print $3}'); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting status of irqbalance..."
    if ! irq_status=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "systemctl status irqbalance | grep Active: | cut -d: -f2-"); then
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting information on uncore frequency..."
    if ! msr_bytes=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S rdmsr 0x620"); then
		echo "Something went wrong :("
		exit 1
	fi

	msr_bytes=${msr_bytes^^}
	if (( ${#msr_bytes} == 3 )); then
		msr_bytes="0${msr_bytes}"
	fi
	uncore_freq_max=$(echo "$msr_bytes" | tail -c+3)
	uncore_freq_max=$(echo "obase=10; ibase=16; $uncore_freq_max" | bc)
	uncore_freq_max=$(( uncore_freq_max * 100 ))

	uncore_freq_min=$(echo "$msr_bytes" | head -c2)
	uncore_freq_min=$(echo "obase=10; ibase=16; $uncore_freq_min" | bc)
	uncore_freq_min=$(( uncore_freq_min * 100 ))

	mixrange "$INGRESS_CPU"
	n_threads=${#array_of_threads[@]}

	if [[ "$ht" == "Enabled" ]]; then
		if (( n_threads % 2 == 0 )); then
			n_cpu=$(( n_threads / 2 ))
		else
			n_cpu=$(( (n_threads+1)/2 ))
		fi
	else
		n_cpu=n_threads
	fi

	SCENARIO="${n_cpu}C${n_threads}T"

	echo "Getting available c-states..."
	if cstates=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/cpu0/cpuidle/state*/name | xargs"); then
		OIFS=$IFS
		IFS=' '
		cstates=($cstates)
		IFS=$OIFS
	else
		echo "Something went wrong :("
		exit 1
	fi

	echo "Getting info about c-states statuses..."
	length=${#cstates[@]}
	cstates_statuses=()
	for ((i=0;i<length;i++)); do
		if ! statuses=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "cat /sys/devices/system/cpu/cpu*/cpuidle/state${i}/disable | sed 's/1/off/g' | sed 's/0/on/g' | sort | uniq -c | xargs"); then
			echo "Something went wrong :("
			exit 1
		fi
		statuses=$(make_prettier "$statuses")
		cstates_statuses+=("$statuses")
	done	
}


make_prettier() {

	if (( $# != 1 )); then
		echo "make_prettier() error: Incorrect number of parameters sent to function."
		exit 1
	fi

	OIFS=$IFS
	IFS=' '
	local arg=($1)
	IFS=$OIFS
	local result
	
	for ((i=0;i<=${#arg[@]}-1;i=i+2)); do
		j=$(( i + 1 ))

		if [[ "${arg[j]}" =~ ^[1-9][0-9]*$ ]]; then
			arg[j]=$(echo "${arg[j]} / 1000" | bc -l | cut -d'.' -f1)
		fi

		if (( i == 0 )); then
			result="${arg[i]}x ${arg[j]}"
		else
			result="$result, ${arg[i]}x ${arg[j]}"
		fi
	done

	echo "$result"
}


prepare_files() {
	echo
    echo "Preparation of folders for storing measurement results..."
	echo
	echo "Create folders on the remote machine in $SSH_USER_HOME_DIR..."
    if sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "mkdir -p \"$DIR_NAME\" \"$DIR_NAME/Nighthawk\" \"$DIR_NAME/Perf\""; then
		echo "The following folders have been created on remote machine:"
		echo "	- $SSH_USER_HOME_DIR/$DIR_NAME"
		echo "	- $SSH_USER_HOME_DIR/$DIR_NAME/Nighthawk"
		echo "	- $SSH_USER_HOME_DIR/$DIR_NAME/Perf"
	else
		echo "Something has gone wrong. Failed to create folders on the remote machine in $SSH_USER_HOME_DIR"
		exit 1
	fi
	echo
	echo "Create folders on the local machine in current directory..."
    if mkdir -p "$DIR_NAME" "$DIR_NAME/Nighthawk" "$DIR_NAME/Perf"; then #"$DIR_NAME/Mbps"
		echo "The following folders have been created on local machine in the current directory:"
		echo "	- ./$DIR_NAME"
		echo "	- ./$DIR_NAME/Nighthawk"
		echo "	- ./$DIR_NAME/Perf"
	else
		echo "Something has gone wrong. Failed to create folders on the local machine in current directory"
		exit 1
	fi
}


nighthawk_test() {

    if (( $# != 1 )); then
        echo "nitghthawk_test() error: Incorrect number of parameters sent to function."
        scp_run
        kill 0
    elif ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "nitghthawk_test() error: Incorrectly stated duration of measurement."
        scp_run
        kill 0
    fi

	echo
	echo "Start of Nighthawk measurement..."
	echo "Some information about measurement:"
	echo "	- Server IP: $NODE_IP"
	echo "	- Port: $PORT"
	echo "	- RPS: $RPS"
	echo "	- Duration: $1 sec"
   
    timestamp=$(date +"%H-%M-%S")

    if [[ "$PROTOCOL" == "http1" ]]; then
        echo "	- Protocol: HTTP/1.1"
		echo
        docker exec "$DOCKER_ID" taskset -c "$NH_CPU" nighthawk_client -p "$PROTOCOL" --connections "$CON" --request-body-size "$RBS" --concurrency "$CONCURRENCY" --rps "$RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt"
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. It failed to run the Nighthawk client inside the $CONTAINER_NAME container. Are you sure Nighthawk and taskset are installed in the container?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			scp_run
			kill 0
		fi
    elif [[ "$PROTOCOL" == "http2" ]]; then
        echo "	- Protocol: HTTP/2"
		echo
        docker exec "$DOCKER_ID" taskset -c "$NH_CPU" nighthawk_client -p "$PROTOCOL" --max-concurrent-streams "$MCS" --max-active-requests "$MAR" --request-body-size "$RBS" --concurrency "$CONCURRENCY" --rps "$RPS"  --duration "$1" "$NODE_IP":"$PORT" > "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt"
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. It failed to run the Nighthawk client inside the $CONTAINER_NAME container. Are you sure Nighthawk and taskset are installed in the container?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			scp_run
			kill 0
		fi
	elif [[ "$PROTOCOL" == "https" ]]; then
        echo "	- Protocol: HTTPS"
		echo
		docker exec "$DOCKER_ID" taskset -c "$NH_CPU" nighthawk_client --max-requests-per-connection "$MRPC" --max-pending-requests "$MPR" --max-active-requests "$MAR" --max-concurrent-streams "$MCS" --address-family v4 "https://$NODE_IP":"$PORT" -p http2 --concurrency "$CONCURRENCY" --rps "$RPS"  --duration "$1" --request-body-size "$RBS" --transport-socket '{"name": "envoy.transport_sockets.tls", "typed_config": { "@type":"type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext","max_session_keys":"0"}}' > "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt"
		stat=$?
		if (( stat != 0 )) && (( stat != 137 )); then #While the script is running, it may be the case that the Nighthawk process is specifically killed. The skip code 137 is there to avoid displaying an error message in this case
			echo
			echo "Something has gone wrong. It failed to run the Nighthawk client inside the $CONTAINER_NAME container. Are you sure Nighthawk and taskset are installed in the container?"
			echo "It is also possible that you have specified the range of threads to be used by taskset, in an incorrect format."
			echo "Possible formats:"
			echo "	- single thread, e.g. 1"
			echo "	- threads listed after a comma, e.g. 1,2,3"
			echo "	- range of threads, e.g. 1-5"
			echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
			echo "Do not use spaces."
			scp_run
			kill 0
		fi
    fi
}


getMbps() {
    RX_UNICAST=$(ethtool -S "$ETH_DEV" | grep rx_unicast | awk '{print $2}' | head -n1)
    TX_UNICAST=$(ethtool -S "$ETH_DEV" | grep tx_unicast | awk '{print $2}' | head -n1)
    SUM_UNICAST_RX_TX=$(( RX_UNICAST + TX_UNICAST ))
    SUM_UNICAST_RX_TX_MB=$(( SUM_UNICAST_RX_TX / (1024 * 1024) ))
    RX_BYTES=$(ethtool -S "$ETH_DEV" | grep rx_bytes | awk '{print $2}' | head -n1)
    TX_BYTES=$(ethtool -S "$ETH_DEV" | grep tx_bytes | awk '{print $2}' | head -n1)
    SUM_BYTES_RX_TX=$(( RX_BYTES + TX_BYTES ))
    SUM_BYTES_RX_TX_MB=$(( SUM_BYTES_RX_TX / (1024 * 1024) ))
}


nighthawk_with_mbps() {
    getMbps

    BEFORE_PACKETS=$SUM_UNICAST_RX_TX_MB
    BEFORE_BYTES=$SUM_BYTES_RX_TX_MB

    nighthawk_test

    getMbps

    AFTER_PACKETS=$SUM_UNICAST_RX_TX_MB
    AFTER_BYTES=$SUM_BYTES_RX_TX_MB

    DIFF_PACKETS=$(( AFTER_PACKETS - BEFORE_PACKETS ))
    DIFF_MEGA_PACKETS_PER_SECOND=$(bc -l <<< $DIFF_PACKETS/$DURATION )
    DIFF_BYTES=$(( AFTER_BYTES - BEFORE_BYTES ))
    DIFF_MEGA_BYTES_PER_SECOND=$(bc -l <<< $DIFF_BYTES/$DURATION )

    echo "DIFF_MEGA_PACKETS: $DIFF_MEGA_PACKETS_PER_SECOND PER_SECOND" > "./$DIR_NAME/Mbps/PACKETS_BYTES.log"
    echo "DIFF_MEGA_BYTES: $DIFF_MEGA_BYTES_PER_SECOND PER_SECOND" >> "./$DIR_NAME/Mbps/PACKETS_BYTES.log"
}


mpstat_ssh() {
    echo
    echo "Enabling mpstat measurement..."
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "mpstat -P ALL 1 $DURATION > \"$DIR_NAME/mpstat_${PROTOCOL}_rps_${RPS}_req_${MAR}.txt\""; then
        echo "Something has gone wrong. It was not possible to use mpstat."
        nighthawk_kill
        scp_run
        kill 0
	fi
}


cpu_state() {
	echo
	echo "Copying the /var/lib/kubelet/cpu_manager_state file to the $SSH_USER_HOME_DIR/$DIR_NAME/ folder under name cpu_${PROTOCOL}_rps_${RPS}_req_${MAR} on the remote machine."
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S cp -r /var/lib/kubelet/cpu_manager_state \"$DIR_NAME/cpu_${PROTOCOL}_rps_${RPS}_req_${MAR}\""; then
		echo "The file could not be copied."
		scp_run
		exit 1
	fi
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S chown \"$USER\":\"$USER\" \"$DIR_NAME/cpu_${PROTOCOL}_rps_${RPS}_req_${MAR}\""; then
		echo "Failed to set $USER as owner of file $SSH_USER_HOME_DIR/$DIR_NAME/cpu_${PROTOCOL}_rps_${RPS}_req_${MAR}"
		exit 1
	fi
}


perf_stat_all_cpus() {
    timestamp=$( date +"%H-%M-%S" )
    sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S perf stat -a -o \"$DIR_NAME/Perf/perf_stat_all_vcpus_$timestamp.txt\" -- sleep $DURATION"
}


perf_record_all_cpus() {
    timestamp=$( date +"%H-%M-%S" )
    sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S perf record -F 99 -a -g -o \"$DIR_NAME/Perf/perf_record_all_vcpus_$timestamp\" -- sleep $DURATION"
}


perf_stat_ingress_cpus() {
    timestamp=$( date +"%H-%M-%S" )
    sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S perf stat -C \"$INGRESS_CPU\" -o \"$DIR_NAME/Perf/perf_stat_ingress_cpus.txt\" -- sleep $DURATION"
}


perf_record_ingress_cpus() {
	echo
    echo "Perf recording Ingress CPUS"
    timestamp=$( date +"%H-%M-%S" )
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S perf record -C \"$INGRESS_CPU\" -F 99 -g -o \"$DIR_NAME/Perf/perf_record_ingress_cpus\" -- sleep $DURATION"; then
        echo "Something has gone wrong. It was not possible to use perf."
        nighthawk_kill
        scp_run
        kill 0
    fi
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S chown \"$USER\":\"$USER\" \"$DIR_NAME/Perf/perf_record_ingress_cpus\""; then
        echo "Failed to set $USER as owner of file $SSH_USER_HOME_DIR/$DIR_NAME/Perf/perf_record_ingress_cpus"
        nighthawk_kill
        kill 0
    fi
}


scp_run() {
	echo
    echo "Copying the results from the remote machine to the local machine and cleaning..."
	echo
	echo "Downloading files to a local machine..."
    if ! sshpass -p "$NODE_PASS" scp -r "$USER"@"$NODE_IP":"\"${SSH_USER_HOME_DIR:-oops}/${STATIC_DIR_NAME:-oops}\"" .; then
		echo "Something has gone wrong. It failed to copy files from the remote machine to the local machine."
		kill 0
	fi
	echo "Deleting results from a remote machine..."
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "rm -r \"${SSH_USER_HOME_DIR:-oops}/${STATIC_DIR_NAME:-oops}\""; then
		echo "Something has gone wrong. The files created on the remote machine could not be deleted."
		kill 0
	fi
	echo "Done"
}


nighthawk_kill() {
	echo
	echo "Killing the Nighthawk process... (If it did not kill itself)"
    nh_pid=$(pgrep -f nighthawk_client)
    if [[ "$nh_pid" == "" ]]; then
		echo "There is nothing to kill :)"
        return 0
    elif [[ "$nh_pid" =~ ^[0-9]+ ]]; then
        echo "The Nighthawk process did not kill itself. Killing..."
        if ! kill -9 $nh_pid; then # Intentionally left without double quote, because kill must be able to iterate over the nh_pid variable
			echo "Something has gone wrong. There was a failure to kill the Nighthawk process."
			scp_run
			kill 0
		fi
		echo
    fi
}


average () {
	local sum=0
	for int in "$@"; do
		sum=$(echo "$sum + $int" | bc -l)
	done
	echo "$sum / $#" | bc -l
}


mixrange(){

	if (( $# != 1 )); then
		echo "mixrange() error: Invalid number of parameters sent to function"
		exit 1
	else
		if ! [[ "$1" =~ ^[0-9][0-9,-]*$ ]]; then
			echo "mixrange() error: Incorrect parameter format"
			exit 1
		fi
	fi

    array_of_threads=()

	local OIFS=$IFS
	IFS=","
	local threads=($1) #Without the quotes, because the string is to be split in this case
	IFS=$OIFS

	for item in "${threads[@]}"; do
	
		if [[ "$item" != *"-"* ]]; then
			array_of_threads+=("$item")
		else
			local OIFS=$IFS
			IFS="-"
			range=($item) #Without the quotes, because the string is to be split in this case
			IFS=$OIFS

			for ((i=range[0];i<=range[1];i++)); do
				array_of_threads+=("$i")
			done
			
		fi
	done
}


pull_utilisation_from_mpstat() {

	if (( $# != 1 )); then
		echo "pull_utilisation_from_mpstat() error: Invalid number of parameters sent to function"
		exit 1
	elif ! [ -f "$1" ]; then
		echo "pull_utilisation_from_mpstat() error: File \"$1\" does not exists"
		exit 1
	fi

	local mpstat_file="$1"
	mixrange "$INGRESS_CPU"
	echo "Measurement No. $counter"
	echo
	echo "Ingress threads utilisation:"
	while IFS= read -r line; do

		if [[ "$line" == *"Average"* ]]; then
			for thread in "${array_of_threads[@]}"; do
				if [[ "$line" == *" $thread "* ]]; then
					local OIFS=$IFS
					IFS=" "
					line=($line) #Without the quotes, because the string is to be split in this case
					IFS=$OIFS
					cpu_load=$(echo "100 - ${line[-1]}" | bc -l)
					echo "thread $thread - cpu load $cpu_load %"
				fi
			done
		fi
		
	done < "$mpstat_file"
	echo
	echo "------------------------------------------------------------------------------------------------------------------------------------"
	echo
}


make_flamegraph_remote() {
	echo
    echo "Creating a flamegraph of results from Perf on a remote machine..."
    file="perf_record_ingress_cpus"
    if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "perf script -i \"$DIR_NAME/Perf/$file\" \
            | \"$SSH_USER_HOME_DIR/FlameGraph/stackcollapse-perf.pl\" \
            | \"$SSH_USER_HOME_DIR/FlameGraph/flamegraph.pl\" > \"$DIR_NAME/Perf/$file.svg\""; then
		echo
		echo "Something has gone wrong. The flamegraph could not be created."
		scp_run
		exit 1
	fi
}


check_if_perf_installed() {
	echo
	echo "Checking that Perf is installed on a remote machine..."
    local pf 
    pf=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "perf version 2> /dev/null")
    if [[ "$pf" =~ (^perf version) ]]; then
		echo "Perf is installed :)"
        return 0
    else
		echo
        echo "Perf is not installed on the remote machine. Installing..."
		echo
        if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" 'sudo -S apt-get update -y && sudo -S apt-get install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)'; then
			echo											# ^^ Specially between single quotes so that $(uname -r) is only resolved on the remote machine side, not locally
			echo "Something has gone wrong. It failed to install Perf on the remote machine."
			exit 1
		fi
    fi
}


check_if_flamegraph_installed() {
	echo
	echo "Checking if there is a FlameGraph repository in the $USER's home folder..."
    local fg_exists
    fg_exists=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "if [ -f $SSH_USER_HOME_DIR/FlameGraph/stackcollapse-perf.pl ] && [ -f $SSH_USER_HOME_DIR/FlameGraph/flamegraph.pl ]; then echo true; else echo false; fi")
    if $fg_exists; then
		echo "FlameGraph's repository has been found!"
        return 0
    else
		echo
        echo "FlameGraph repository not found in home folder."
        if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "git clone https://github.com/brendangregg/FlameGraph"; then
			echo "Something went wrong, the FlameGraph repository could not be downloaded to the $USER's home folder :("
			exit 1
		fi
    fi
}


check_for_blocking() {
	echo
	echo "Checking in the Nighthawk output file (./$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt) if blocking has occurred...."
	echo
    local check_blocking
    check_blocking=$(< "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt" grep Blocking)

    if [[ "$check_blocking" != "" ]]; then
        echo "BLOCKING"
		blocking=true
    else
		echo "There was no blocking!"
		blocking=false
	fi
}


ctrl_c(){
	echo
	echo "CTRL + C sequence detected"
	nighthawk_kill
	scp_run
	kill 0
}


check_if_installed(){

	if (( $# != 2 )); then
		echo "check_if_installed() error: Incorrect number of parameters send to function."
		exit 1
	elif ! [[ "$1" =~ (^local$)|(^remote$) ]]; then
		echo "check_if_installed() error: Incorrectly specified on which machine to check if $2 is installed"
		exit 1
	fi

	echo
	echo "Checking that $2 is installed on the $1 machine..."
	if [[ "$1" == "remote" ]]; then
		check=$(sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "dpkg -l | grep \"ii  $2 \"")
	else
		check=$(dpkg -l | grep "ii  $2 ")
	fi

	if [[ "$check" =~ ^ii"  "$2' ' ]]; then
		echo "$2 is installed on the $1 machine!"
	else
		echo "$2 is not installed on the $1 machine :("
		apt_install "$1" "$2"
	fi
}


apt_install(){

	installation_allowed=(
		"_jq_"
		"_git_"
		"_sshpass_"
		"_sysstat_"
		"_xlsx2csv_"
		"_ruby_"
		"_python3_"
		"_msr-tools_"
	)

	if (( $# != 2 )); then
		echo "apt_install() error: Incorrect number of parameters send to function."
		exit 1
	elif ! [[ "$1" =~ (^local$)|(^remote$) ]]; then
		echo "apt_install() error: Incorrectly specified on which machine to carry out the installation."
		exit 1
	elif ! [[ "${installation_allowed[*]}" =~ _$2_ ]]; then
		echo "apt_install() error: $2 is not permitted to be installed."
		exit 1
	fi
	echo
	echo "Do you want to install $2 on the $1 machine?"
	echo "Default: yes"
    read -rep "Answer: " answer
    echo

	if [[ "$answer" == "yes" ]] || [[ "$answer" == "y" ]] || [[ "$answer" == "" ]]; then	
		if [[ "$1" == "local" ]]; then
			if ! sudo -S apt-get update -y; then
				echo "Something went wrong, failed to update the package lists :("
				exit 1
			fi 
			if ! sudo -S apt-get install -y "$2"; then
				echo "Something went wrong, failed to install $2 on the local machine :("
				exit 1
			fi 
		elif [[ "$1" == "remote" ]]; then
			if ! sshpass -p "$NODE_PASS" ssh "$USER"@"$NODE_IP" "sudo -S apt-get update -y && sudo -S apt-get install -y \"$2\""; then
				echo "Something went wrong, failed to install $2 on the remote machine :("
				exit 1
			fi 
		fi
		echo
	else
		exit 1
	fi
}


prepare_report(){
	echo
	echo "Preparing the report header..."
	{
		echo "Measurement taken on $(date).";
		echo;
		echo "Information about the remote machine:";
		echo "OS: $OS"; 
		echo "Kernel: $kernel_version"; 
		echo "NIC driver: $NIC_driver"; 
		echo "NIC firmware: $NIC_firmware"; 
		echo "Docker version: $docker_version"; 
		echo "Kubernetes version: $kube_version"; 
		echo "Calico version: $calico_version"; 
		echo "Istio version: $istio_version"; 
		echo "Hyper Threading: $ht"; 
		echo "Turbo Boost: $tb"; 
		echo "Governor: $governor"; 
		echo "Max cpu freq: $cpu_max_freq [MHz]"; 
		echo "Min cpu freq: $cpu_min_freq [MHz]"; 
		echo "Proc name: $proc_name"; 
		echo "Socket(s): $n_sockets"; 
		echo "Core(s) per socket: $cps"; 
		echo "Stepping: $stepping"; 
		echo "NUMA node(s): $n_numa_nodes";
		echo "Max uncore freq: $uncore_freq_max [MHz]"; 
		echo "Min uncore freq: $uncore_freq_min [MHz]";
		echo "Status of Irqbalance:$irq_status";
		echo "Memory for ingress (limits/requests): $memory";
		echo "Ingress --concurrency: $ingress_concurrency";
		echo "Ingress cpu: $INGRESS_CPU ($n_threads)";
		echo "Nighthawk cpu: $NIGHTHAWK_CPU";
		echo "Sidecar cpu: $SIDECAR_CPU";
		echo "C-states:";
		length=${#cstates[@]};
		for ((i=0;i<length;i++)); do
			echo "	- ${cstates[i]}: ${cstates_statuses[i]}";
		done
		echo;
		echo;
	} >> "$STATIC_DIR_NAME/report.txt"

	if [[ "$NOTE" != "" ]]; then
		{ echo "Note:"; echo "$NOTE"; echo; echo; } >> "$STATIC_DIR_NAME/report.txt"
	fi
}

collect_results(){
	echo
	echo "Collecting the results of measurements..."
	if ! [ -f "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt" ]; then
		echo "collect_results() error: Nighthawk result file not found in $DIR_NAME/Nighthawk/ folder"
		exit 1
	fi

	mixrange "$NH_CPU"
	number_of_clients=${#array_of_threads[@]}
	total_RPS=$(( number_of_clients * RPS ))
	achieved_RPS=$(< "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt" grep benchmark.http_2xx | awk '{print $3}')
	P90=$(< "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt" grep ' 0\.9 ' | tail -n1 | xargs | cut -d' ' -f3-)
	P99=$(< "$DIR_NAME/Nighthawk/nh_rps_${RPS}_${PROTOCOL}_${SCENARIO}.txt" grep ' 0\.990' | tail -n1 | xargs | cut -d' ' -f3-)

	if (( counter == 1 )); then
		echo "No.,Core/Thread,Protocol,RPS per worker,Requested RPS,Achieved RPS,P90 latency,P99 latency,Blocked" >> "$STATIC_DIR_NAME/results.csv"
	fi
	
	echo "$counter,$SCENARIO,$PROTOCOL,$RPS,$total_RPS,$achieved_RPS,$P90,$P99,$blocking" >> "$STATIC_DIR_NAME/results.csv"
}

check_dependencies(){
	echo
	echo "Checking that dependencies are met on the remote and local machine..."
	check_if_installed "local" "sshpass"
	test_ssh_connection
	check_if_installed "remote" "jq"
	check_if_installed "remote" "msr-tools"

	if $use_mpstat; then
		check_if_installed "remote" "sysstat"
	fi

	if $use_perf; then
		check_if_perf_installed
		check_if_installed "remote" "git"
		check_if_flamegraph_installed
	fi
}


parse_commandline "$@"
handle_passed_args_count
NODE_IP=${_positionals[0]}
DIR_NAME="sm_ingress-$(date +"%d-%m-%y_%"H-%M-%S)"
STATIC_DIR_NAME="$DIR_NAME"
DOCKER_ID=$(docker ps -q -l -f name="^$CONTAINER_NAME$" -f status=running)

if ! valid_ip "$NODE_IP"; then
	echo "Incorrectly stated IP"
	exit 1
fi

if [[ "$PORT" == "" ]]; then
	echo "No port number was given. This parameter is required. (-p|--port)"
	exit 1
elif ! [[ "$PORT" =~ ^[0-9]{1,5}$ ]]; then
	echo "Incorrectly specified port. (-p|--port)"
	exit 1
fi

if [[ "$RPS" == "" ]]; then
	echo "The number of requests per second is not stated. This parameter is required. (-r|--rps)"
	exit 1
elif ! [[ "$RPS" =~ ^[1-9][0-9]*$ ]]; then
	echo "Incorrectly specified requests per second. (-r|--rps)"
	exit 1
fi

if [[ "$MAX_RPS" == "" ]]; then
	MAX_RPS=$RPS
	loop=false
elif ! [[ "$MAX_RPS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Incorrectly specified parameter --max-rps."
	exit 1
elif (( MAX_RPS < RPS )); then
	echo "The parameter specified in --max-rps must be greater than that specified in --rps"
	exit 1
fi

if ! [[ "$STEP_RPS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Incorrectly specified parameter --step-rps."
	exit 1
fi

if [[ "$NH_CPU" == "" ]]; then
	echo "No threads were specified for Nighthawk to use. This parameter is required. (-N|--nh-cpu)"
	exit 1
elif ! [[ "$NH_CPU" =~ ^[0-9][0-9,-]*$ ]]; then
	echo "Incorrectly specified range of threads for use by Nighthawk clients."
	echo "Possible formats:"
	echo "	- single thread, e.g. 1"
	echo "	- threads listed after a comma, e.g. 1,2,3"
	echo "	- range of threads, e.g. 1-5"
	echo "The given formats can be combined, e.g. 1,2,3,7-10,15"
	echo "Do not use spaces."
	exit 1
fi

if ! [[ "$use_perf" =~ (^true$)|(^false$) ]]; then
	echo "Incorrectly specified whether to use Perf."
	exit 1
fi

if ! [[ "$use_mpstat" =~ (^true$)|(^false$) ]]; then
	echo "Incorrectly specified whether to use mpstat."
	exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified measurement duration"
	exit 1
fi

if ! [[ "$KILL_DELAY" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified kill delay"
	exit 1
fi

if ! [[ "$MAR" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified max number of active requests (MAR)"
	exit 1
fi

if ! [[ "$MCS" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified max number of concurrent streams (MCS)"
	exit 1
fi

if ! [[ "$CON" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified number of connections (CON)"
	exit 1
fi

if ! [[ "$RBS" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified request body size (RBS)"
	exit 1
fi

if ! [[ "$MPR" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified max pending requests (MPR)"
	exit 1
fi

if ! [[ "$MRPC" =~ ^[0-9]+$ ]]; then
	echo "Incorrectly specified max requests per connection (MRPC)"
	exit 1
fi

if ! [[ "$PROTOCOL" =~ ^http[12s]$ ]]; then
	echo "Incorrectly specified protocol"
	exit 1
fi

if ! [[ "$DOCKER_ID" =~ ^[a-z0-9]+$ ]]; then
    echo "The container named $CONTAINER_NAME was not found."
    exit 1
fi

check_dependencies
get_info
counter=1
for ((RPS;RPS<=MAX_RPS;RPS=RPS+STEP_RPS)); do
	if $loop; then
		echo
		echo "--------------------- Measurement No. $counter ---------------------"
		DIR_NAME="${STATIC_DIR_NAME}/${RPS}RPS"
	fi
	echo
	echo "PREPARING"
	prepare_files
	cpu_state
	if (( counter == 1 )); then
		prepare_report
	fi

	if $use_perf; then
		echo
		echo "NIGTHAWK MEASUREMENT WITH PERF"
		perf_record_ingress_cpus &
		nighthawk_test "$DURATION" & sleep $(( DURATION + KILL_DELAY ));
		nighthawk_kill
		sleep 10
		check_for_blocking
	fi

	if $use_mpstat; then
		echo
		echo "NIGTHAWK MEASUREMENT WITH MPSTAT"
		mpstat_ssh &
		nighthawk_test "$DURATION" & sleep $(( DURATION + KILL_DELAY ))
		nighthawk_kill
		sleep 10
		check_for_blocking
	fi

	echo
	echo "NIGTHAWK MEASUREMENT"
	nighthawk_test "$DURATION" & sleep $(( DURATION + KILL_DELAY ));
	nighthawk_kill
	sleep 10
	check_for_blocking

	echo
	echo "POSTPROCESSING"
	if $use_perf; then
		make_flamegraph_remote;
		sleep 5
	fi

	scp_run

	if $use_mpstat; then
		echo
		echo "Pulling results from Mpstat..."
		pull_utilisation_from_mpstat "$DIR_NAME/mpstat_${PROTOCOL}_rps_${RPS}_req_${MAR}.txt" >> "$STATIC_DIR_NAME/threads_utilisation_report_mpstat.txt"
		sleep 5
	fi
	collect_results
	counter=$(( counter + 1 ))
done
< "$STATIC_DIR_NAME/results.csv" column -t -s',' -o"    |    " >> "$STATIC_DIR_NAME/report.txt"
echo
echo "All done! Measurements completed :)"