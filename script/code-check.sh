#!/usr/bin/env bash

checkout_sh_log="$(pwd)/checkout_sh_log.log"
echo -e "LogPath: ${checkout_sh_log}\n"
echo -ne '' > $checkout_sh_log

progress_bar() {
	if [ "${1}" = "green" ]; then
		echo -e "${2} .................................................. 100% \033[32;40m${3}\033[0m"
	elif [ "${1}" = "red" ]; then
		echo -e "${2} .................................................. 100% \033[31;40m${3}\033[0m"
	fi
}

log() {
	echo -e "$(date "+%Y-%m-%d %H:%M:%S") ${2}\n${3}" >> ${1}
}

lt_len_func(){
	result=$(echo $base_result | egrep --color -o "${1}")
	if [ "${6}" = "m" ]; then
		len=$(echo -n $result | wc -m)
	elif [ "${6}" = "w" ]; then
		len=$(echo -n $result | wc -w)
	fi
	if [[ $len -lt ${3} ]]; then
		final_result=0
		log $checkout_sh_log 'ERROR' "${4} Error, '${2}' missing or invalid in ${5}, should match '${1}'${7}"
	fi
}

final_result_func(){
	if [ "$final_result" = "0" ]; then
		false_list[${#false_list[*]}]=${1}
	elif [ "$final_result" = "1" ]; then
		true_list[${#true_list[*]}]=${1}
	elif [ "$final_result" = "2" ]; then
		null_list[${#null_list[*]}]=${1}
	elif [ "$final_result" = "3" ]; then
		skip_list[${#skip_list[*]}]=${1}
	fi
}

readme_func(){
	# ensure that at least one of the values in $parameter_list is found in $1 section of the $base_result

	match_para=1
	all_para=
	section=$(echo "$base_result" | sed -n ":a;/### ${1}/{:b;n;\${H;b c};/^###/b c;H;b b};n;b a;:c;x;p")
	for((e=0;e<${#parameter_list[*]};e++));  do
		para=${parameter_list[$e]}
		result=$(echo "$section" | grep "$para")
		if [[ -z $all_para ]]; then
			all_para="'${para}'"
		else
			all_para="${all_para} or '${para}'"
		fi
		if [[ -n "$result" ]]; then
			match_para=0
			break
		fi
	done
	if [[ ${match_para} != 0 ]]; then
		if [[ ${#parameter_list[*]} > 1 ]]; then
			log $checkout_sh_log 'ERROR' "${2} Error, one of ${all_para} must be found in ### ${1} and none were found"
		else
			log $checkout_sh_log 'ERROR' "${2} Error, ${all_para} was not found in ### ${1}"
		fi
		final_result=0
	fi
	unset parameter_list
}

config_func() {
	# ensure that at least one of the values in $parameter_list is found in $base_result

	config_func_result=1
	all_para=
	for((e=0;e<${#parameter_list[*]};e++));  do
		para=${parameter_list[$e]}
		result=$(echo $base_result | egrep --color -o "$para")
		if [[ -z ${all_para} ]]; then
			all_para="'${para}'"
		else
			all_para="${all_para} or '${para}'"
		fi
		if [[ -n "$result" ]]; then
			config_func_result=0
			break
		fi
	done
	if [[ ${config_func_result} != 0 ]]; then
		final_result=0
		if [[ ${#parameter_list[*]} > 1 ]]; then
			log $checkout_sh_log 'ERROR' "${2} Error, one of ${all_para} must be found in ${1} config and none were found"
		else
			log $checkout_sh_log 'ERROR' "${2} Error, ${all_para} was not found in ${1} config"
		fi
	fi
	unset parameter_list
}

helm_dir_func(){
	final_result=1
	if [ ! -f "${1}/${2}" ]; then
		final_result=2
	fi
	final_result_func "helm/${2}"
}

end_preparation_func() {
	if [ "${2}" = "0" ];then
		null_list[${#null_list[*]}]=${3}
		log $checkout_sh_log 'ERROR' "${1} Can't find ${3}"
	elif [ "${2}" = "2" ];then
		skip_list[${#skip_list[*]}]=${3}
	fi
}


check_folder_name_func(){
    files=$(ls ${1})
    for filename in $files; do
        if [ ! -f "${1}/$filename" ] && [ ! -d "${1}/$filename" ]; then
                log $checkout_sh_log 'ERROR' "${1} find file or folder name with space"
        fi
        if [ -d "${1}/$filename" ]; then
          check_folder_name_func "${1}/$filename"
        fi
    done
}


dockerfile() {
  oldIFS=${IFS}
  IFS=$'\n'
	for word in `cat ${3}`; do
		len=$(echo -n $word | wc -w)
		if [ "$len" = '1' ]; then
		  index_notes=$(echo "$word" | grep "##")
		  if [ "$index_notes" = "" ]; then
                    index_notes=$(echo "$word" | grep "#")
		    notes='#'
		  else
		    notes='##'
		  fi
		  if [ "$index_notes" = "" ]; then
		    for i_l in "RUN" "FROM" "ENV" "CMD" "ADD"; do
		      index_notes=$(echo "$word" | grep "$i_l")
		      if [ "$index_notes" != "" ]; then
		        final_result=0
		        log $checkout_sh_log 'ERROR' "${2} '$i_l' in Dockerfile Error"
		      fi
		    done
		  else
		    len2=$(echo -n $word | wc -m)
		    if [ "$notes" = '##' ]; then
		      if [ $len2 -lt 3 ]; then
		        final_result=0
		        log $checkout_sh_log 'ERROR' "${2} '##' in Dockerfile Error"
		      fi
		    elif [ "$notes" = '#' ]; then
          if [ $len2 -lt 2 ]; then
		        final_result=0
		        log $checkout_sh_log 'ERROR' "${2} '#' in Dockerfile Error"
		      fi
		    fi
		  fi
		fi
	done
	IFS=${oldIFS}
	result1=$(egrep --color -o '.*VER' ${3})
	result2=$(egrep --color '.*VER' ${3})
	if [[ ! "$result1" == "" ]] && [ ${#result1} -lt ${#result2} ] ; then
		global_dockerfile_ver=1
	fi
}

readme_md() {
	declare -a parameter_list=("kpi.sh")
	readme_func "KPI" ${3}
	declare -a parameter_list=("Validation")
	readme_func "Contact" ${3}
	declare -a parameter_list=("docker run" "kubectl exec")
	readme_func "Docker Image" ${3}
	declare -a parameter_list=("Stage1 Contact")
	readme_func "Contact" ${3}
	lt_len_func "### Introduction.*?#" "Introduction length" 22 ${3} "README.md" "w"
}

kpi_sh() {
	result='encode'$(grep --color -o "\*.*" ${3})
	len=$(echo -n $result | wc -m)
	if [ $len -lt 8 ]; then
		final_result=0
		log $checkout_sh_log 'ERROR' "${3} Can't find primary in kpi.sh"
	fi
}

validate_sh() {
	lt_len_func "DOCKER_IMAGE=.* " "DOCKER_IMAGE" 14 ${3} "validate.sh" "m"
	lt_len_func '/../../script/validate.sh' "/../../script/validate.sh" 1 ${3} "validate.sh" "w"
	lt_len_func '/../../script/overwrite.sh' "/../../script/overwrite.sh" 1 ${3} "validate.sh" "w"
}

build_sh() {
	lt_len_func '/../../script/build.sh' "/../../script/build.sh" 1 ${3} "build.sh" "w"
}

cmakelist() {
	lt_len_func " GNR " "GNR" 3 ${3} "CMakeLists.txt" "m"
	lt_len_func "add_workload\(.*?\)" "add_workload" 15 ${3} "CMakeLists.txt" "m"
	lt_len_func "add_testcase\(.*?\)" "add_testcase" 15 ${3} "CMakeLists.txt" "m"
	lt_len_func '_gated' "_gated" 1 ${3} "CMakeLists.txt" "w"
	lt_len_func '_pkm' "_pkm" 1 ${3} "CMakeLists.txt" "w" ", please include at least a commented message about this test type"
}

k8s_config() {
	declare -a parameter_list=('include')
	config_func  'k8s' ${3}
	declare -a parameter_list=('apiVersion')
	config_func 'k8s' ${3}
	#declare -a parameter_list=('labels' 'affinity*' 'AFFINITY*' 'nodeSelector')
	#config_func 'k8s' ${3}
	declare -a parameter_list=('template')
	config_func 'k8s' ${3}
}

cluster_config() {
	declare -a parameter_list=('include')
	config_func 'cluster' ${3}
	declare -a parameter_list=('cluster')
	config_func 'cluster' ${3}
	declare -a parameter_list=('labels')
	config_func 'cluster' ${3}
}

helm_dir(){
	helm_dir_func ${3} "Chart.yaml"
	helm_dir_func ${3} "values.yaml"
}

head_preparation(){
	echo -e "${1}\n------------------Code Checking----------------------"
	is_dockerfile=0
	is_kpi_sh=0
	is_readme_md=0
	is_validate_sh=0
	is_build_sh=0
	is_cmakelist=0
	is_k8s_config=0
	is_cluster_config=0
	is_helm_dir=2
	global_dockerfile_ver=0
	unset true_list false_list skip_list null_list
	declare -a true_list false_list skip_list null_list
}

check_tools() {
	if [ -f ${3} ] || [ -d ${3} ]; then
		final_result=1
		base_result="$(cat ${3})"
	else
		return
	fi

	if [[ ${2} == Dockerfile* ]]; then
		is_dockerfile=1
		dockerfile ${1} ${2} ${3}
	elif [ ${2} = "kpi.sh" ]; then
		is_kpi_sh=1
		kpi_sh ${1} ${2} ${3}
	elif [ ${2} = "README.md" ]; then
		is_readme_md=1
		readme_md ${1} ${2} ${3}
	elif [ ${2} = "validate.sh" ]; then
		is_validate_sh=1
		validate_sh ${1} ${2} ${3}
	elif [ ${2} = "build.sh" ]; then
		is_build_sh=1
		build_sh ${1} ${2} ${3}
	elif [ ${2} = "CMakeLists.txt" ]; then
		is_cmakelist=1
		cmakelist ${1} ${2} ${3}
	elif [ ${2} = "kubernetes-config.yaml.m4" ]; then
		is_k8s_config=1
		k8s_config ${1} ${2} ${3}
	elif [ ${2} = "cluster-config.yaml.m4" ]; then
		is_cluster_config=1
		cluster_config ${1} ${2} ${3}
	elif [ ${2} = "helm" ]; then
		if [ "$is_k8s_config" = "0" ];then
			is_k8s_config=2
		fi
		is_helm_dir=1
		helm_dir ${1} ${2} ${3}
	else
		return
	fi
	final_result_func ${2}
}

end_preparation(){
	end_preparation_func ${1} $is_dockerfile "Dockerfile"
	end_preparation_func ${1} $is_kpi_sh "kpi.sh"
	end_preparation_func ${1} $is_readme_md "README.md"
	end_preparation_func ${1} $is_validate_sh "validate.sh"
	end_preparation_func ${1} $is_build_sh "build.sh"
	end_preparation_func ${1} $is_cmakelist "CMakeLists.txt"
	end_preparation_func ${1} $is_k8s_config "kubernetes-config.yaml.m4"
	end_preparation_func ${1} $is_cluster_config "cluster-config.yaml.m4"
	end_preparation_func ${1} $is_helm_dir 'helm'
	if [[ "$global_dockerfile_ver" == "0" ]]; then
		log $checkout_sh_log 'ERROR' "${1}/<global_dockerfile> Can't find VER"
		for((e=0;e<${#true_list[*]};e++));  do
			if [[ ${true_list[$e]} == Dockerfile* ]]; then
				false_list[${#false_list[*]}]=${true_list[$e]}
				true_list[$e]="clean_placeholder"
			fi
		done
	fi
}

print_check_result(){
	for((e=0;e<${#true_list[*]};e++));  do
		if [ "${true_list[$e]}" != "clean_placeholder" ];then
			progress_bar 'green' "${true_list[$e]}" "[OK]"
		fi
	done
	for((e=0;e<${#skip_list[*]};e++));  do
		if [ "${skip_list[$e]}" != "clean_placeholder" ];then
			progress_bar 'green' "${skip_list[$e]}" "[SKIP]"
		fi
	done
	for((e=0;e<${#false_list[*]};e++));  do
		if [ "${false_list[$e]}" != "clean_placeholder" ];then
			progress_bar 'red' "${false_list[$e]}" "[Check]"
		fi
	done
	for((e=0;e<${#null_list[*]};e++));  do
		if [ "${null_list[$e]}" != "clean_placeholder" ];then
			progress_bar 'red' "${null_list[$e]}" "[Null]"
		fi
	done
}

main_func(){
  check_folder_name_func $now_repo

	files=$(ls $now_repo)
	head_preparation $now_repo
	for filename in $files; do
		check_tools $now_repo $filename $now_repo'/'$filename 2> /dev/null
	done
	end_preparation $now_repo
	print_check_result $now_repo
	echo ''
}

now_repo=$1
main_func
