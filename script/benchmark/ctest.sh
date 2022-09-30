#!/bin/bash -e

if [ "$#" -eq 0 ]; then
    echo "Usage: [options]"
    echo "--loop <number>       Run the ctest commands sequentially."
    echo "--burst <number>      Run the ctest commands simultaneously."
    echo "--run <number>        Run the ctest commands on same SUT (only with cumulus)."
    echo "--test-config <yaml>  Specify the test-config yaml."
    echo "--nohup               Run the script as a daemon."
    echo "--stop                Kill all ctest sessions."
    echo "--set <vars>          Set variable values between burst and loop iterations."
    echo "--continue            Ignore any error and continue the burst and loop iterations." 
    echo "--prepare-sut         Prepare cloud SUT for reuse."
    echo "--reuse-sut           Reuse the cloud SUT previously prepared."
    echo "--cleanup-sut         Cleanup cloud SUT."
    echo "--dry-run             Generate the testcase configurations and then exit."  
    echo "ctest options apply"
    echo ""
    echo "<vars> accepts the following formats:"
    echo "VAR=str1 str2 str3    Enumerate the variable values."
    echo "VAR=1 3 5 ...20 [|7]  Increment variable values linearly, with mod optionally."
    echo "VAR=1 2 4 ...32 [35|] Increment variable values exponentially, with mod optionally."
    echo "VAR1=n1 n2/VAR2=n1 n2 Permutate variable 1 and 2."
    echo "The values are repeated if insufficient to cover the loops."
    exit 3
fi

run_as_nohup=""
args=()
for var in "$@"; do
    case "$var" in
    --nohup)
        run_as_nohup="1"
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
    nohup "$0" "${args[@]}" > nohup.out 2>&1 &
    echo "tail -f nohup.out to monitor progress"
    exit 0
fi

run=1
burst=1
loop=1
step=1
args=()
steps=()
contf=0
test_config="$(readlink -f "$TEST_CONFIG" || echo "")"
prepare_sut=0
sut=()
cleanup_sut=0
reuse_sut=0
dry_run=0
for var in "$@"; do
    case "$var" in
    --loop=*)
        loop="${var/--loop=/}"
        ;;
    --loop)
        loop="-1"
        ;;
    --burst=*)
        burst="${var/--burst=/}"
        ;;
    --burst)
        burst="-1"
        ;;
    --run=*)
        run="${var/--run=/}"
        ;;
    --run)
        run="-1"
        ;;
    --prepare-sut)
        prepare_sut=1
        ;;
    --set=*)
        steps+=("${var/--set=/}")
        ;;
    --set)
        step="-1"
        ;;
    --test-config=*)
        test_config="$(readlink -f "${var/--test-config=/}")"
        ;;
    --test-config)
        test_config="-1"
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
    --dry-run)
        dry_run=1
        ;;
    *)
        if [ "$loop" = "-1" ]; then
            loop="$var"
        elif [ "$burst" = "-1" ]; then
            burst="$var"
        elif [ "$run" = "-1" ]; then
            run="$var"
        elif [ "$step" = "-1" ]; then
            steps+=("$var")
            step=1
        elif [ "$test_config" = "-1" ]; then
            test_config="$(readlink -f "$var")"
        else
            args+=("$var")
        fi
        ;;
    esac
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
    echo "$step1" | tr '/' '\n' | awk '{
        split($1,kv,"=")
        $1=kv[2]
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
            vars[kv[1]][k]=$k
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


for loop1 in $(seq 1 $loop); do
    loop_prefix="$(date +%m%d-%H%M%S)-"
    while [ -d "$loop_prefix"* ]; do
        sleep 1s
        loop_prefix="$(date +%m%d-%H%M%S)-"
    done
    [ $prepare_sut = 1 ] && loop_prefix="sut-"
    [ $cleanup_sut = 1 ] && loop_prefix=""
    pids=()
    for burst1 in $(seq 1 $burst); do
        echo "Loop: $loop1 Burst: $burst1 Run: $run"
        if [ "$burst" = "1" ]; then
            export TEST_PREFIX="$loop_prefix"
        else
            export TEST_PREFIX="${loop_prefix}r$burst1-"
        fi
        export TEST_CONFIG="$test_config"
        if [ ${#values[@]} -gt 0 ]; then
            tmp="$(mktemp)"
            if [ -n "$TEST_CONFIG" ]; then
                cp -f "$TEST_CONFIG" $tmp
            fi
            export TEST_CONFIG="$tmp"
            echo "*:" >> $tmp
            for var1 in "${values[@]}"; do
                values1=($(echo "$var1" | tr ' ' '\n'))
                key1="${values1[0]}"
                val1="${values1[$(( (((loop1-1)*burst+burst1-1) % (${#values1[@]}-1))+1 ))]}"
                echo "$key1: $val1"
                echo "  $key1: \"$val1\"" >> $tmp
            done
            tmp_files+=($tmp)
        fi
        (   
            export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --run_stage_iterations=$run"
            [ $prepare_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --run_stage=provision,prepare"
            [ $cleanup_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --cleanup-sut"
            [ $reuse_sut = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --reuse-sut"
            [ $dry_run = 1 ] && export CTESTSH_OPTIONS="$CTESTSH_OPTIONS --dry-run"
            set -x
            ctest "${args[@]}"
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
