#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

print_help () {
    echo "Usage: [options]"
    echo "--loop <number>       Run the ctest commands sequentially."
    echo "--burst <number>      Run the ctest commands simultaneously."
    echo "--run <number>        Run the ctest commands on same SUT (only with cumulus)."
    echo "--config <yaml>       Specify the test-config yaml."
    echo "--options <options>   Specify additional backend options."
    echo "--nohup [logs]        Run the script as a daemon."
    echo "--daemon [logs]       Run the script via daemonize."
    echo "--stop [prefix]       Kill all ctest sessions without prefix or kill specified session with prefix input as workload benchmark namespace name."
    echo "--set <vars>          Set variable values between burst and loop iterations."
    echo "--continue            Ignore any error and continue the burst and loop iterations." 
    echo "--prepare-sut         Prepare cloud SUT for reuse."
    echo "--reuse-sut           Reuse the cloud SUT previously prepared."
    echo "--cleanup-sut         Cleanup cloud SUT."
    echo "--dry-run             Generate the testcase configurations and then exit."
    echo "--testcase            Run the test case exactly as specified."
    echo "--noenv               Clean environment variables before proceeding with the tests."
    echo "--check-docker-image  Check image availability before running the workload."
    echo "--push-docker-image <mirror>     Push the workload image(s) to the mirror registry."
    echo ""
    echo "<vars> accepts the following formats:"
    echo "VAR=str1 str2 str3    Enumerate the variable values."
    echo "VAR=1 3 5 ...20 [|7]  Increment variable values linearly, with mod optionally."
    echo "VAR=1 2 4 ...32 [35|] Increment variable values exponentially, with mod optionally."
    echo "VAR1=n1 n2/VAR2=n1 n2 Permutate variable 1 and 2."
    echo "The values are repeated if insufficient to cover the loops."
    echo ""
    echo "Subset of the following ctest options apply:"
    /usr/bin/ctest --help | sed -n '/--progress/,/--help/{p}'
    exit 3
}

if [ "$#" -eq 0 ]; then
    print_help
fi

run_with_nohup=""
run_with_daemon=""
no_env=""
args=()
stop=""
last=""
for var in "$@"; do
    case "$var" in
    --nohup=*)
        run_with_nohup="${var#--nohup=}"
        ;;
    --nohup)
        run_with_nohup="nohup.out"
        ;;
    --daemon=*)
        run_with_daemon="${var#--daemon=}"
        ;;
    --daemon)
        run_with_daemon="daemon.out"
        ;;
    --noenv)
        no_env="1"
        ;;
    --stop=*)
        stop="$var"
        ;;
    --stop)
        stop="--stop="
        ;;
    *)
        case "$last" in
        --stop)
            stop="--stop=$var"
            ;;
        --nohup)
            if [[ "$var" != "--"* ]]; then
                run_with_nohup="$var"
            else
                args+=("$var")
            fi
            ;;
        --daemon)
            if [[ "$var" != "--"* ]]; then
                run_with_daemon="$var"
            else
                args+=("$var")
            fi
            ;;
        *)
            args+=("$var")
            ;;
        esac
        ;;
    esac
    last="$var"
done

if [ -n "$stop" ]; then
    if [ "$stop" = "--stop=all" ] || [ "$stop" = "--stop=" ]; then
        OWNER="$( (git config user.name || id -un) 2> /dev/null)-"
        DIRPATH="$(pwd)"
        while [[ "$DIRPATH" = */* ]]; do
            if [ -r "$DIRPATH/CMakeCache.txt" ]; then
                backend="$(grep "BACKEND:UNINITIALIZED=" "$DIRPATH/CMakeCache.txt" | cut -f2 -d=)"
                options="$(grep "${backend^^}_OPTIONS:UNINITIALIZED=" "$DIRPATH/CMakeCache.txt" | cut -f2- -d=)"
                if [[ "$options" = *"--owner="* ]]; then
                    OWNER="$(echo "x$options" | sed 's|.*--owner=\([^ ]*\).*|\1|')-"
                fi
                break
            fi
            DIRPATH="${DIRPATH%/*}"
        done
    else
        OWNER="${stop#--stop=}"
    fi
    cmd="docker ps -f name=$(echo $OWNER | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')"
    if [ "$($cmd | wc -l)" -ne 2 ] && [ "$stop" != "--stop=all" ]; then
        echo "None or multiple ctest instances detected:"
        echo ""
        $cmd --format '{{.Names}}\t\t{{.ID}}\t{{.Status}}'
        echo ""
        echo "Please identify the instance with: ./ctest.sh --stop=<prefix> or ./ctest.sh --stop=all"
        exit 3
    fi
    for id1 in $($cmd --format '{{.ID}}'); do
        echo "send SIGINT to $id1"
        #docker exec -u root $id1 bash -c 'kill -s SIGINT $(ps -o pid= -a -x)' || true
        docker kill --signal SIGINT $id1 || true
    done
    exit 0
fi

if [ -n "$run_with_nohup" ]; then
    echo "============================================================="
    echo " Warning: Use the --daemon option instead.                   "
    echo ""
    echo " --daemon [logs] Run the script via daemonize.               "
    echo ""
    echo " Note --daemon does not take external environment variables. "
    echo " Use --set or --config to set variables instead.             "
    echo "============================================================="
    run_with_nohup="$(readlink -f "$run_with_nohup")"
    if [ -n "$no_env" ]; then
        nohup env -i "HOME=$HOME" "http_proxy=$http_proxy" "https_proxy=$https_proxy" "no_proxy=$no_proxy" "PATH=$PATH" "$0" "${args[@]}" > "$run_with_nohup" 2>&1 &
        disown
    else
        nohup "$0" "${args[@]}" > "$run_with_nohup" 2>&1 &
        disown
    fi
    echo "tail -f $(basename "$run_with_nohup") to monitor progress"
    exit 0
elif [ -n "$run_with_daemon" ]; then
    run_with_daemon="$(readlink -f "$run_with_daemon")"
    echo "=== daemon: $0 ${args[@]} ===" > "$run_with_daemon"
    daemonize -a -c "$(pwd)" -e "$run_with_daemon" -o "$run_with_daemon" -p "$run_with_daemon.pid" "$(readlink -f "$0")" "${args[@]}" || (
        echo "Failed to daemonize the task."
        echo "Please install 'daemonize' if you have not."
        exit 3
    )
    tail --pid $(cat "$run_with_daemon.pid") -f "$run_with_daemon"
    rm -f "$run_with_daemon.pid"
    exit 0
elif [ -n "$no_env" ]; then
    env -i "HOME=$HOME" "http_proxy=$http_proxy" "https_proxy=$https_proxy" "no_proxy=$no_proxy" "PATH=$PATH" "$0" "${args[@]}" 
    exit 0
fi

run=1
burst=1
loop=1
step=1
args=()
steps=()
contf=0
prepare_sut=0
sut=()
cleanup_sut=0
reuse_sut=0
dry_run=0
run_as_ctest=1
options=""
empty_vars=()
last_var=""
CTESTSH_CMDLINE=""
for var in "$@"; do
    if [[ "$var" = *" "* ]]; then
        CTESTSH_CMDLINE="$CTESTSH_CMDLINE \"${var//\"/\\\"}\""
    else
        CTESTSH_CMDLINE="$CTESTSH_CMDLINE $var"
    fi
    case "$var" in
    --loop=*)
        loop="${var/--loop=/}"
        run_as_ctest=0
        ;;
    --loop)
        run_as_ctest=0
        ;;
    --burst=*)
        burst="${var/--burst=/}"
        run_as_ctest=0
        ;;
    --burst)
        run_as_ctest=0
        ;;
    --run=*)
        run="${var/--run=/}"
        ;;
    --run)
        ;;
    --prepare-sut)
        prepare_sut=1
        run_as_sut=0
        ;;
    --set=*)
        if [[ "$var" =~ ^--set=[A-Za-z0-9_]*=$ ]]; then
          empty_vars+=(${var/--set=/})
        else 
          steps+=("${var/--set=/}")
        fi
        ;;
    --set)
        ;;
    --test-config=*|--config=*)
        export TEST_CONFIG="${var/*=/}"
        ;;
    --test-config|--config)
        ;;
    --options=*)
        export CTESTSH_OPTIONS="$CTESTSH_OPTIONS ${var/--options=/}"
        ;;
    --options)
        ;;
    --continue)
        contf=1
        ;;
    --cleanup-sut)
        cleanup_sut=1
        ;;
    --reuse-sut)
        reuse_sut=1
        ;;
    --testcase=*)
        args+=("-R" "^${var#--testcase=}$")
        ;;
    --testcase)
        ;;
    --dry-run)
        dry_run=1
        ;;
    --check-docker-image)
        export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --check-docker-image"
        ;;
    --push-docker-image=)
        export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --push-docker-image=${var#--push-docker-image=}"
        ;;
    --push-docker-image)
        ;;
    --help|-help|-h|-H|"/?")
        print_help
        ;;
    -V|--verbose|-VV|--extra-verbose|--debug|--progress|--output-on-failure|-F|-Q|--quiet|-N|-U|--union|--rerun-failed|--schedule-random|--version|-version|-j|--parallel|-O|--output-log|-L|--label-regex|-R|--tests-regex|-E|--exclude-regex|-LE|--label-exclude|--repeat-until-fail|--max-width|-I|--tests-information|--timeout|--stop-time)
        args+=("$var")
        ;;
    *)
        case "$last_var" in
        --loop)
            loop="$var"
            ;;
        --burst)
            burst="$var"
            ;;
        --run)
            run="$var"
            ;;
        --set)
            if [[ "$var" =~ ^[A-Za-z0-9_]*=$ ]]; then
              empty_vars+=("$var")
            else
              steps+=("$var")
            fi
            step=1
            ;;
        --test-config|--config)
            export TEST_CONFIG="$var"
            ;;
        --options)
            export CTESTSH_OPTIONS="$CTESTSH_OPTIONS $var"
            options=""
            ;;
        --testcase)
            args+=("-R" "^$var$")
            ;;
        -j|--parallel|-O|--output-log|-L|--label-regex|-R|--tests-regex|-E|--exclude-regex|-LE|--label-exclude|--repeat-until-fail|--max-width|-I|--tests-information|--timeout|--stop-time)
            args+=("$var")
            ;;
        --push-docker-image)
            export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --push-docker-image=$var"
            ;;
        *)
            echo "Unknown option: $last_var $var"
            exit 3
            ;;
        esac
        ;;
    esac
    last_var="$var"
done
export CTESTSH_CMDLINE="${CTESTSH_CMDLINE## }"

if [ "$loop" = "-1" ]; then
    loop=1
fi

if [ "$burst" = "-1" ]; then
    burst=1
fi

if [ "$run" = "-1" ]; then
    run=1
fi

if [ $prepare_sut = 1 ] || [ $cleanup_sut = 1 ]; then
    loop=1
    burst=1
    run=1
fi

if [ $reuse_sut = 1 ]; then
    burst=1
fi

readarray -t values < <(for step1 in "${steps[@]}"; do
    if [ $(echo "$step1" | tr '/' '\n' | wc -l) -lt $(echo "$step1" | tr '=' '\n' | wc -l) ]; then
        echo "$step1" | tr '/' '\n'
    else
        echo "$step1"
    fi | awk '{
        kk=gensub(/^([^=]*)=.*/,"\\1",1,$1)
        $1=gensub(/^[^=]*=(.*)/,"\\1",1,$1)
        if ($NF~/^\|[0-9]+$/ || $NF~/^[0-9]+\|$/) {
            modstr=$NF
            NF=NF-1
        } else {
            modstr=""
        }
        if (($NF ~ /^\.\.\./) && (NF>3)) {
            stop=gensub(/^\.\.\./,"",1,$NF)
            $NF=""
            current=$(NF-1)
            delta=current-$(NF-2)
            if ($(NF-2)-$(NF-3)==delta) {
                for(i=NF-1;(current+0) <= (stop+0);i++) {
                    $i=current
                    current+=delta
                }
            }
            if ($(NF-3)!=0 && $(NF-2)!=0) {
                factor=$(NF-1)/$(NF-2)
                if ($(NF-3)*factor==$(NF-2)) {
                    for(i=NF-1;(current+0) <= (stop+0);i++) {
                        $i=current
                        current*=factor
                    }
                }
            }
        }
        if (modstr~/^\|[0-9]+/) {
            modval=gensub(/\|/,"",1,modstr)
            j=0
            for(i=1;i<=NF;i++) {
                if (($i % modval)==0) {
                   j++
                   if (i!=j) $j=$i
                }
            }
            NF=j
        }
        if (modstr~/^[0-9]+\|$/) {
            modval=gensub(/\|/,"",1,modstr)
            j=0
            for(i=1;i<=NF;i++) {
                if ($i!=0) {
                    if ((modval % $i)==0) {
                        j++
                        if (i!=j) $j=$i
                    }
                }
            }
            NF=j
        }
        for(k=1;k<=NF;k++)
            vars[kk][k]=$k
    }
    END {
        nk=1
        for(k in vars) {
           nk*=length(vars[k])
        }
        nk1=nk
        nk2=1
        for(k in vars) {
           varn=length(vars[k])
           nk1=nk1/varn
           printf "%s ", k
           for(r=0;r<nk2;r++)
               for(i=1;i<=varn;i++)
                   for (j=0;j<nk1;j++)
                      printf "%s ", vars[k][i]
           nk2=nk2*varn
           printf "\n"
        }
    }'
done)

tmp_files=()
remove_tmp_files () {
    rm -f "${tmp_files[@]}"
    tmp_files=()
}
trap 'remove_tmp_files' ERR EXIT

test_config=""
if [ -n "$TEST_CONFIG" ]; then
    if [ -r "$TEST_CONFIG" ]; then
        test_config="$(readlink -f "$TEST_CONFIG")"
    else
        echo "$TEST_CONFIG not found"
        exit 3
    fi
fi

set_variable () {
    if [ "$1" = "EVENT_TRACE_PARAMS" ]; then
        export CTESTSH_EVENT_TRACE_PARAMS="${2//%20/ }"
    else
        echo "$1=$2"
        echo "  $1: \"$2\"" >> "$3"
    fi
}

get_uniq_prefix () {
    (
        flock -e 9
        local last_prefix="$(cat .timestamp 2>/dev/null || true)"
        local loop_prefix="$(date +%m%d-%H%M%S)"
        while [ "$loop_prefix" = "$last_prefix" ]; do
            sleep 1s
            loop_prefix="$(date +%m%d-%H%M%S)"
        done
        echo "$loop_prefix" > .timestamp
        echo "$loop_prefix"
    ) 9< "$(pwd)"
}

uniq_prefix="$(get_uniq_prefix)-"
for loop1 in $(seq 1 $loop); do
    if [ "$loop" = "1" ]; then
        loop_prefix="$uniq_prefix"
    else
        loop_prefix="${uniq_prefix}l$loop1-"
        [[ "$burst" = "1" ]] || loop_prefix="${loop_prefix%-}"
    fi
    [ $cleanup_sut = 1 ] || [ $run_as_ctest = 1 ] && loop_prefix=""
    [ $prepare_sut = 1 ] && loop_prefix="sut-"
    pids=()
    for burst1 in $(seq 1 $burst); do
        echo "Loop: $loop1 Burst: $burst1 Run: $run"
        if [ "$burst" = "1" ]; then
            export CTESTSH_PREFIX="$loop_prefix"
        else
            export CTESTSH_PREFIX="${loop_prefix}b$burst1-"
        fi
        export CTESTSH_CONFIG="$test_config"
        export CTESTSH_EVENT_TRACE_PARAMS="undefined"
        if [ ${#values[@]} -gt 0 ] || [ ${#empty_vars[@]} -gt 0 ]; then
            tmp="$(mktemp)"
            if [ -r "$CTESTSH_CONFIG" ]; then
                echo "# ctestsh_config: $CTESTSH_CONFIG" >> "$tmp"
                cat "$CTESTSH_CONFIG" >> "$tmp"
            fi
            export CTESTSH_CONFIG="$tmp"
            echo -e "\n# ctestsh_overwrite:\n*:" >> "$tmp"
            for var1 in "${values[@]}"; do
                values1=($(echo "$var1" | tr ' ' '\n'))
                key1="${values1[0]}"
                val1="${values1[$(( (((loop1-1)*burst+burst1-1) % (${#values1[@]}-1))+1 ))]}"
                set_variable "$key1" "$val1" "$tmp"
            done
            for var1 in "${empty_vars[@]}"; do
                set_variable "${var1%=}" "" "$tmp"
            done
            tmp_files+=("$tmp")
        fi
        (
            export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --run_stage_iterations=$run"
            [ $prepare_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --prepare-sut"
            [ $cleanup_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --cleanup-sut"
            [ $reuse_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --reuse-sut"
            [ $dry_run = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --dry-run"
            set -x
            /usr/bin/ctest "${args[@]}"
        ) &
        pids+=($!)
        [ "$burst" = "1" ] || sleep 60s
    done
    if [ $contf = 1 ]; then
        wait ${pids[@]} || true
    else
        wait ${pids[@]}
    fi
    remove_tmp_files
done
