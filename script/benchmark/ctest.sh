#!/bin/bash -e

print_help () {
    echo "Usage: [options]"
    echo "--loop <number>       Run the ctest commands sequentially."
    echo "--burst <number>      Run the ctest commands simultaneously."
    echo "--run <number>        Run the ctest commands on same SUT (only with cumulus)."
    echo "--config <yaml>       Specify the test-config yaml."
    echo "--options <options>   Specify additional backend options."
    echo "--nohup               Run the script as a daemon."
    echo "--stop                Kill all ctest sessions."
    echo "--set <vars>          Set variable values between burst and loop iterations."
    echo "--continue            Ignore any error and continue the burst and loop iterations." 
    echo "--prepare-sut         Prepare cloud SUT for reuse."
    echo "--reuse-sut           Reuse the cloud SUT previously prepared."
    echo "--cleanup-sut         Cleanup cloud SUT."
    echo "--dry-run             Generate the testcase configurations and then exit."
    echo "--testcase            Run the test case exactly as specified."
    echo "--noenv               Clean environment variables before proceeding with the tests."
    echo ""
    echo "<vars> accepts the following formats:"
    echo "VAR=str1 str2 str3    Enumerate the variable values."
    echo "VAR=1 3 5 ...20 [|7]  Increment variable values linearly, with mod optionally."
    echo "VAR=1 2 4 ...32 [35|] Increment variable values exponentially, with mod optionally."
    echo "VAR1=n1 n2/VAR2=n1 n2 Permutate variable 1 and 2."
    echo "The values are repeated if insufficient to cover the loops."
    echo ""
    echo "Subset of the following ctest options apply:"
    ctest --help | sed -n '/--progress/,/--help/{p}'
    exit 3
}

if [ "$#" -eq 0 ]; then
    print_help
fi

run_as_nohup=""
no_env=""
args=()
for var in "$@"; do
    case "$var" in
    --nohup)
        run_as_nohup="1"
        ;;
    --noenv)
        no_env="1"
        ;;
    --stop)
        kill -9 -a $(ps auxwww | grep ctest | awk '{print$2}') 2> /dev/null || echo -n ""
        exit 0
        ;;
    *)
        args+=("$var")
        ;;
    esac
done

if [ -n "$run_as_nohup" ]; then
    if [ -n "$no_env" ]; then
        nohup env -i "HOME=$HOME" "http_proxy=$http_proxy" "https_proxy=$https_proxy" "no_proxy=$no_proxy" "PATH=$PATH" "$0" "${args[@]}" > nohup.out 2>&1 &
        disown -h $!
    else
        nohup "$0" "${args[@]}" > nohup.out 2>&1 &
        disown -h $!
    fi
    disown
    echo "tail -f nohup.out to monitor progress"
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
for var in "$@"; do
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
        *)
            echo "Unknown option: $last_var $var"
            exit 3
            ;;
        esac
        ;;
    esac
    last_var="$var"
done

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

for loop1 in $(seq 1 $loop); do
    loop_prefix="$(date +%m%d-%H%M%S)-"
    while [ -d "$loop_prefix"* ]; do
        sleep 1s
        loop_prefix="$(date +%m%d-%H%M%S)-"
    done
    [ $cleanup_sut = 1 ] || [ $run_as_ctest = 1 ] && loop_prefix=""
    [ $prepare_sut = 1 ] && loop_prefix="sut-"
    pids=()
    for burst1 in $(seq 1 $burst); do
        echo "Loop: $loop1 Burst: $burst1 Run: $run"
        if [ "$burst" = "1" ]; then
            export CTESTSH_PREFIX="$loop_prefix"
        else
            export CTESTSH_PREFIX="${loop_prefix}r$burst1-"
        fi
        export TEST_CONFIG="$test_config"
        export CTESTSH_EVENT_TRACE_PARAMS="undefined"
        if [ ${#values[@]} -gt 0 ] || [ ${#empty_vars[@]} -gt 0 ]; then
            tmp="$(mktemp)"
            if [ -n "$TEST_CONFIG" ]; then
                cp -f "$TEST_CONFIG" $tmp
            fi
            export TEST_CONFIG="$tmp"
            echo -e "\n*:" >> $tmp
            for var1 in "${values[@]}"; do
                values1=($(echo "$var1" | tr ' ' '\n'))
                key1="${values1[0]}"
                val1="${values1[$(( (((loop1-1)*burst+burst1-1) % (${#values1[@]}-1))+1 ))]}"
                set_variable "$key1" "$val1" "$tmp"
            done
            for var1 in "${empty_vars[@]}"; do
                set_variable "${var1%=}" "" "$tmp"
            done
            tmp_files+=($tmp)
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
    done
    if [ $contf = 1 ]; then
        wait ${pids[@]} || true
    else
        wait ${pids[@]}
    fi
    remove_tmp_files
done
