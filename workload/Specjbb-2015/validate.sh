#!/bin/bash -e

# set -x

WORKLOAD=${WORKLOAD:-specjbb_2015_openjdk}
SPECJBB_RUN_TYPE=${1:-HBIR_RT_LOADLEVELS}
OPTION=${2:-openjdk_multijvm_base}
SPECJBB_WORKLOAD_CONFIG=$3

JDK=$(echo "${OPTION}" | cut -d_ -f1)
MODE=$(echo "${OPTION}" | cut -d_ -f2)

echo "Running Specjbb for ${JDK} version $JDK_PACKAGE"

# Logs Setting
DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"

# ##############################
# Workload tunable parameters
# ##############################

# Load variables from env file
. "$DIR/scripts/specjbb.env.sh"

workload_configuration=$(echo "${SPECJBB_WORKLOAD_CONFIG}" | cut -d_ -f3)
echo "Loading [${workload_configuration}] configuration"
default_test_config="$DIR/configs/$workload_configuration/test_config.yaml"
user_test_config=${TEST_CONFIG}

# Temporarily use the test config provided in the $DIR/configs/$workload_configuration/ folder to get the
# default run configuration

TEST_CONFIG=${default_test_config}

# Load default values form $DIR/configs/$workload_configuration/test_config.yaml --set value will be ignored at this stage
. "$DIR/../../script/overwrite.sh"

# Now overwrite those defaults with the user provided values (--set and/or --config parameters)
if [[ -z "$user_test_config" ]]; then
    unset TEST_CONFIG
else 
    TEST_CONFIG=${user_test_config}
fi

# Load ctest command line variables: now user specified values will overwrite the defaults
# The second call to overwrite.sh is necessary to get the user vales.
. "$DIR/../../script/overwrite.sh"

# For getting hugepage settings for Kuberentes and cumulus setup @example HUGEPAGE_MEMORY_NUM=2Mb*16Gi
read -r hugepage_size memory_requested_gi < <(awk -F '*' '{print $1, $2}' <<<"${HUGEPAGE_MEMORY_NUM}")                                   # 2Mb
read -r hugepage_size huge_page_unit_size < <(awk 'match($0, /([0-9]{1,})([Gi|Mb|Gb]{2})/, a) {print a[1], a[2]}' <<<"${hugepage_size}") # 2 MB
read -r memory_requested_gi_value < <(awk 'match($0, /([0-9]{1,})/, a) {print a[1]}' <<<"${memory_requested_gi}")                        # 10

if [[ "${huge_page_unit_size,,}" =~ ^(m|M) ]]; then
    page_multiplier=512
    kb_power_of=1
    huge_page_unit_size=Mb
else
    page_multiplier=1
    kb_power_of=2
    huge_page_unit_size=Gi
fi

HUGEPAGE_UNIT_SIZE=${huge_page_unit_size}
HUGEPAGE_NUMBER_OF_PAGES=$((memory_requested_gi_value * page_multiplier))
HUGEPAGE_SIZE_KB=$((hugepage_size * (1024 ** kb_power_of)))

HUGEPAGE_LIMIT="${memory_requested_gi_value}Gi"
HUGEPAGE_REQUEST="${memory_requested_gi_value}Gi"
HUGEPAGE_KB8_DIRECTIVE=$([[ "${huge_page_unit_size}" =~ ^(m|M) ]] && echo "hugepages-2Mi" || echo "hugepages-1Gi")

function valid_jvm_unit() {
    user_value=$1
    result=ok
    if [ -n "${user_value}" ]; then
        unit_value=$(echo "${user_value}" | grep -Po "[^0-9]{1,}" | awk '{print tolower($0)}')
        if [[ ! "$unit_value" =~ ^(k|m|g)$ ]]; then
            result=error
        fi
    fi

    echo $result
}

# ensure the units specified match what is expected from the JVM
[[ $(valid_jvm_unit "${SPECJBB_XMN}") == "error" ]] && (echo "Invalid unit type for SPECJBB_XMN. Valid units are g|m|k. Please amend!" && exit 1)
[[ $(valid_jvm_unit "${SPECJBB_XMS}") == "error" ]] && (echo "Invalid unit type for SPECJBB_XMS. Valid units are g|m|k. Please amend!" && exit 2)
[[ $(valid_jvm_unit "${SPECJBB_XMX}") == "error" ]] && (echo "Invalid unit type for SPECJBB_XMX. Valid units are g|m|k. Please amend!" && exit 3)
[[ -n "${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}" &&
    $(
        echo "${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}" |
            grep -P "^([0-9]+[\.]{0,1}[0-9]{0,}[,]{1}){2}[0-9]{0,}[\.]{0,1}[0-9]{0,}$" >/dev/null
        echo $?
    ) -ne 0 ]] &&
    (echo "Invalid Tier thread multiplier(s). Please amend!" && exit 2)

# Run container with specific user (non-root)
WORKLOAD_USER_ID=70001

# Workload Setting ( replace key=value with (lowercase)key:(original uri_encoded)value; )
WORKLOAD_PARAMS=($(for var in ${!SPECJBB@}; do echo "$var"; done | tr "\n" " ") WORKLOAD_USER_ID JDK_PACKAGE)

# Huge page configuration on backend docker (bare metal), needs to be setup by the user, otherwise include params for all other backends
if [ ! "$BACKEND" == "docker" ]; then
    WORKLOAD_PARAMS+=($(for var in ${!HUGEPAGE@}; do echo "$var"; done | tr "\n" " "))
fi

# Docker Setting
DOCKER_IMAGE="$DIR/images/$JDK/Dockerfile.1.$JDK-$JDK_PACKAGE"

if [[ ! -f "$DOCKER_IMAGE" ]]; then
    printf "\n\t\x1b[31mIncorrect JDK_PACKAGE value (%s). The file %s does not exists.\033[0m\n\n" "$JDK_PACKAGE" "$DOCKER_IMAGE"
    exit 3
fi

IFS='.' read -ra JDK_MAJOR_VERSION <<< "$JDK_PACKAGE"

if [[ "${JDK_MAJOR_VERSION[0]}" -lt "15" && "${PLATFORM}" =~ ARM* ]]; then
    printf "\n\t\x1b[31mJDK version %s does not have support for %s\033[0m\n\n" "${JDK_MAJOR_VERSION[0]}" "$PLATFORM"
    exit 4
fi

# Docker settings replace key=value with -e key="[uri_encoded]value"
DOCKER_OPTIONS=$(
    for var in ${!SPECJBB@}; do
        val=$(echo "${!var}" | tr -d "\n" | perl -p -e 's/([^\S])/sprintf("%%%02X", ord($1))/eg')
        echo "-e $var=${val}"
    done
)

DOCKER_OPTIONS="${DOCKER_OPTIONS} --cap-add SYS_NICE --user ${WORKLOAD_USER_ID}:${WORKLOAD_USER_ID} -e HUGEPAGE_MEMORY_NUM=${HUGEPAGE_MEMORY_NUM} -e PLATFORM=${PLATFORM}"

# Kubernetes Setting (replace key=value with -Dkey="[uri_encoded]value")
RECONFIG_OPTIONS=$(
    for var in ${!SPECJBB@} ${!HUGEPAGE@}; do
        val=$(echo "${!var}" | tr -d "\n" | perl -p -e 's/([^\S])/sprintf("%%%02X", ord($1))/eg')
        echo "-D$var=${val}"
    done
)

RECONFIG_OPTIONS="${RECONFIG_OPTIONS} -DMODE=${MODE} -DDOCKER_IMAGE=${DOCKER_IMAGE} -DPLATFORM=${PLATFORM} -DWORKLOAD_USER_ID=${WORKLOAD_USER_ID} -DIMAGEARCH=${IMAGEARCH}"

JOB_FILTER="job-name=specjbb"

# Event Trace Parameter
if [[ "$MODE" == *"composite"* ]]; then
    EVENT_TRACE_PARAMS=${EVENT_TRACE_PARAMS:-"roi,Starting COMPOSITE,COMPOSITE has stopped"}
elif [[ "$MODE" == *"multijvm"* ]]; then
    EVENT_TRACE_PARAMS=${EVENT_TRACE_PARAMS:-"roi,Starting MULTICONTROLLER,Controller has stopped"}
fi

SCRIPT_ARGS="--test_case=${TESTCASE} --platform=${PLATFORM}"

. "$DIR/../../script/validate.sh"
