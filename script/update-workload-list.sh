#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
BUILD_DIR="$DIR/../_wltable"

format_name () {
    echo "${1/-/}" | sed 's/^[^:]*: *//' | sed 's/;.*//' | sed 's/and .*//' |  sed 's/(.*//' | sed 's/[ .]*$//' | tr -d '`[]' | sed 's|\(.*\), *\(.*\)|\2 \1|'
}

calc_nimages () {
    batch=$(( $(nproc) / 4 ))

    cd "$BUILD_DIR"
    mkdir -p nimages.raw cluster-config kubernetes-config docker-config compose-config
    for p in $(cat "$DIR"/../workload/platforms); do
        for w in "$DIR"/../workload/*/build.sh; do
            w="${w/\/build.sh/}"
            w="$(basename "$w")"
            echo " CMAKE PLATFORM=$p WORKLOAD=$w" 1>&2
            ( 
                mkdir -p "$BUILD_DIR/$w"
                cd "$BUILD_DIR/$w"
                cmake -DPLATFORM=$p -DACCEPT_LICENSE=ALL -DREGISTRY= -DRELEASE=updateworkload -DBACKEND=terraform -DTERRAFORM_OPTIONS=--nosutinfo -DTERRAFORM_SUT='static aws gcp azure tencent alicloud' -DBENCHMARK=workload/$w/ ../..
            ) &
            if [ $(jobs -p | wc -w) -ge $batch ]; then
                wait -n || true
            fi
        done
        wait

        for w in "$DIR"/../workload/*/build.sh; do
            w="${w/\/build.sh/}"
            w="$(basename "$w")"
            echo " PLATFORM=$p WORKLOAD=$w" 1>&2
            (
                cd "$BUILD_DIR/$w"
                make bom > "$BUILD_DIR"/nimages.raw/$w.$p

                ./ctest.sh -j $batch --dry-run --docker --nobomlist --nosutinfo --nodockerconf 2>&1 | grep Failed
                cat workload/$w/logs-*/cluster-config.yaml >> "$BUILD_DIR"/cluster-config/$w.$p 2> /dev/null || true
                cat workload/$w/logs-*/docker-config.yaml >> "$BUILD_DIR"/docker-config/$w.$p 2> /dev/null || true
                find workload/$w -maxdepth 1 -type d -name "logs-*" | xargs rm -rf

                ./ctest.sh -j $batch --dry-run --compose --nobomlist --nosutinfo --nodockerconf 2>&1 | grep Failed
                cat workload/$w/logs-*/cluster-config.yaml >> "$BUILD_DIR"/cluster-config/$w.$p 2> /dev/null || true
                cat workload/$w/logs-*/compose-config.yaml >> "$BUILD_DIR"/compose-config/$w.$p 2> /dev/null || true
                find workload/$w -maxdepth 1 -type d -name "logs-*" | xargs rm -rf

                ./ctest.sh -j $batch --dry-run --kubernetes --nobomlist --nosutinfo --nodockerconf 2>&1 | grep Failed
                cat workload/$w/logs-*/cluster-config.yaml >> "$BUILD_DIR"/cluster-config/$w.$p 2> /dev/null || true
                cat workload/$w/logs-*/kubernetes-config.yaml >> "$BUILD_DIR"/kubernetes-config/$w.$p 2> /dev/null || true
                find workload/$w -maxdepth 1 -type d -name "logs-*" | xargs rm -rf

            ) &
            if [ $(jobs -p | wc -w) -ge $batch ]; then
                wait -n || true
            fi
        done
        wait
    done

    awk '
/^BOM of/ {
    p1=gensub(/\/.*/,"",1,$3)
    w=""
}
/^# workload/ {
    w=gensub(/[\/]$/,"",1,$2)
    pm[w][p1]=1
}
/^# image[:\/]/ {
    if(w!="") im[w][$3]=1
}
END {
    for(w in pm) {
        pp=""
        for (p1 in pm[w])
            pp=pp" "p1
        print w" "length(im[w])pp
    }
}' "$BUILD_DIR"/nimages.raw/* > "$BUILD_DIR"/nimages.txt
}

calc_nnodes () {
    awk '
/^\s*cluster:/ {
    if (l>0) a[l]=0
    l=0
}
/^\s*-\s*labels:/ {
    l++
}
END {
    if (l>0) a[l]=0
    for (x in a) print x
}' "$BUILD_DIR"/cluster-config/$1.* | sort -n
}

calc_accel () {
   awk '
/HAS-SETUP-DLB/ {
  a["DLB"]=1
}
/HAS-SETUP-DSA/ {
  a["DSA"]=1
}
/HAS-SETUP-HABANA-GAUDI/ {
  a["GAUDI"]=1
}
/HAS-SETUP-INTEL-ARC/ {
  a["ARC"]=1
}
/HAS-SETUP-INTEL-ACM/ {
  a["ACM"]=1
}
/HAS-SETUP-FLEX/ {
  a["FLEX"]=1
}
/HAS-SETUP-IAA/ {
  a["IAA"]=1
}
/HAS-SETUP-INFERENTIA-NEURON/ || /HAS-SETUP-NVIDIA-CUDA/ {
  a["CUDA"]=1
}
/HAS-SETUP-PVC/ {
  a["PVC"]=1
}
/HAS-SETUP-QAT/ {
  a["QAT"]=1
}
/HAS-SETUP-RDMA/ {
  a["RDMA"]=1
}
END {
  for (k in a)
    print "`"k"`"
}' "$BUILD_DIR"/cluster-config/$1.* | sort -n
}

calc_kcn () {
    kcn=""
    for wc in "$BUILD_DIR"/docker-config/$1.*; do
        if [ -n "$(cut -f2 -d'"' "$wc" 2> /dev/null)" ]; then
            kcn="${kcn}ND"
            break
        fi
    done
    if [ -n "$(cat "$BUILD_DIR"/compose-config/$1.* 2> /dev/null)" ]; then
        kcn="${kcn}C"
    fi
    if [ -n "$(cat "$BUILD_DIR"/kubernetes-config/$1.* 2> /dev/null)" ] || [ -r "${buildsh/build.sh/kubernetes-config.yaml.m4}" ] || [ -d "${buildsh/build.sh/helm}" ]; then
        kcn="${kcn}K"
    fi
    if [ -z "$kcn" ]; then
        kcn="N"
    fi
}

write_table () {
    echo "| Category | Workload | Platform | Accel | #NODE | #IMG | IMPL | PERF | S1&nbsp;Contact | S2&nbsp;Contact | Keywords | Permission[*](#access-permission) |"
    echo "|:---|:---|:---|:--:|:--:|:--:|:--:|:--:|:---|:---|:---|:---|"

    for buildsh in "$1"/*/build.sh; do
        readme="${buildsh/build.sh/README.md}"
        if [ -r "$buildsh" ] && [ -r "$readme" ]; then
            workload_dirname="${buildsh/\/build.sh/}"
            workload_dirname="$(basename "$workload_dirname")"
            section=0
            name=""
            category="Misc"
            platform=""
            keywords=""
            permission=""
            stage1=""
            stage2=""
            kcn=""
            while IFS= read line; do
                line="$(echo "$line" | sed 's/\r//')"
                case "$line" in 
                "#### "* | "### "* | "## "* | "# "*)
                    if [[ "$line" = *"Index Info"* ]] || [[ "$line" = *"Contact"* ]]; then
                        section=1
                    else
                        section=0
                    fi
                    ;;
                "- Name: "* | "* Name: "*)
                    if [ $section -eq 1 ]; then
                        name="\`$(echo "${line/* Name: /}" | sed -e 's/ *$//' -e 's/^ *//' | tr -d '`')\`"
                    fi
                    ;;
                "- Category: "* | "* Category: "*)
                    if [ $section -eq 1 ]; then
                        c1="$(echo "${line/* Category: /}" | sed -e 's/ *$//' -e 's/^ *//' | tr -d '`')"
                        for c in $CATEGORIES; do
                            [[ "${c,,}" = "${c1,,}" ]] && category="$c"
                        done
                    fi
                    ;;
                "- Keywords: "* | "* Keywords: "*)
                    if [ $section -eq 1 ]; then
                        keywords="$(echo "${line/* Keywords: /}" | tr 'a-z' 'A-Z' | sed -e 's/ *$//' -e 's/^ *//' -e 's|[,]\s*|<span/>|g')"
                    fi 
                    ;;   
                "- Permission: "* | "* Permission: "*)
                    if [ $section -eq 1 ]; then
                        permission="$(echo "${line/* Permission: /}" | sed -e 's/ *$//' -e 's/^ *//')"
                    fi
                    ;;
                "- Integrator: "*|"* Integrator: "*|"- Integration: "*|"* Integration: "*|"- Stage1 Contact: "*|"* Stage1 Contact:"*)
                    [ $section -eq 1 ] && stage1="\`$(format_name "$line")\`"
                    ;;
                "- Software Stack: "*|"* Software Stack: "*|"- PAIV Stack: "*|"* PAIV Stack: "*|"- Stage2 Contact: "*|"* Stage2 Contact: "*|"- Domain Expert: "*|"* Domain Expert: "*|"- Domain Expertise: "*|"* Domain Expertise: "*|"- Workload Author: "*|"* Workload Author: ")
                    [ $section -eq 1 ] && stage2="\`$(format_name "$line")\`"
                    ;;
                esac
            done < "$readme"

            platform=" $(awk -v w="${1/*\/workload/workload}/$workload_dirname" '$1==w{$1="";$2="";print$0}' "$BUILD_DIR/nimages.txt") "
            platform="$(for p1 in $(cat "$DIR/../workload/platforms"); do
                            if [[ "$platform" = *" $p1 "* ]]; then
                                case "$p1" in
                                ROME) 
                                  p1="RO"
                                  ;;
                                BERGAMO)
                                  p1="BG"
                                  ;;
                                MILAN)
                                  p1="MI"
                                  ;;
                                GENOA)
                                  p1="GA"
                                  ;;
                                TURIN)
                                  p1="TR"
                                  ;;
                                ARMv*)
                                  p1="${p1/ARMv/R}"
                                  ;;
                                esac
                                echo '`'$p1'`'
                            fi
                        done | awk '
{
    if (l!="") {
        l=l"<span/>"$1
    } else {
        l=$1
    }
}
!((NR-0)%4) {
    print l
    l=""
}
END{
    if (l!="") print l
}' | tr '\n' ' ')"
            accelerators="$(calc_accel "$workload_dirname" | awk '
{
    if (l!="") {
        l=l"<span/>"$1
    } else {
        l=$1
    }
}
!((NR-0)%4) {
    print l
    l=""
}
END{
    if (l!="") print l
}' | tr '\n' ' ')"
            nimages="$(awk -v w="${1/*\/workload/workload}/$workload_dirname" '$1==w{print$2}' "$BUILD_DIR/nimages.txt")"
            nnodes="$(calc_nnodes "$workload_dirname" | tr '\n' '/')"
            calc_kcn "$workload_dirname"
            report="$(awk -v w="$workload_dirname" '
/^\s*###\s*/ {
    h=gensub(/^\s*###\s*/,"",1,$0)
    h=tolower("#" gensub(/[ .]/,"-","g",h))
}
/WSF%20Performance%20Reports/ {
    tsc=h
}
/WL%20Slides/ {
    tsc=h
}
/%2FTSC%2FWL%20Slides%2F/ {
    tsc=h
}
/\/IAGS-DPGPerformanceProgram\// {
    pdt=h
}
/\/nexperformancedataapprovalforum\// {
    jet=h
}
END {
    r=""
    if (tsc!="") {
        r="[`T`]("w"/README.md"tsc")"
    }
    if (pdt!="") {
        if (r!="") r=r"<span/>"
        r=r"[`P`]("w"/README.md"pdt")"
    }
    if (jet!="") {
        if (r!="") r=r"<span/>"
        r=r"[`J`]("w"/README.md"jet")"
    }
    if (r!="") print r
}' "$readme")"
            contact_rel="$workload_dirname/README.md#$(grep -q -E '^\s*### Contact' "$readme" && echo "contact" || echo "index-info")"
            nnodes="${nnodes%/}"
            [ -z "$nnodes" ] || nnodes="\`$nnodes\`"
            [ -z "$nimages" ] || nimages="\`$nimages\`"
            [ -z "$kcn" ] || kcn="\`$kcn\`"
            echo "| \`$category\` | [$name]($workload_dirname) | $platform | $accelerators | ${nnodes} | $nimages | $kcn | $report | [$stage1]($contact_rel) | [$stage2]($contact_rel) | $keywords | $permission |"
        fi
    done | tee "$BUILD_DIR"/README.unsorted | sort
}

find "$DIR"/../workload "$DIR"/../image "$DIR"/../stack \( -name "build.sh" -o -name "validate.sh" -o -name "kpi.sh" \) -exec chmod a+rx {} \; 

echo "rm -rf $BUILD_DIR"
find "$BUILD_DIR" -maxdepth 1 | xargs rm -rf
mkdir -p "$BUILD_DIR"

COLORS="#a73107 #e24b6e #16ade4 #ade416 #16e4b4 #2b5969 #e4c916 #716f6e #ad5907 #adad07"
CATEGORIES="DataServices ML/DL/AI HPC uServices Synthetic Networking Media Edge Storage Misc"
calc_nimages
for readme1 in "$DIR"/../workload/README.md; do
    if [ -r "$readme1" ]; then 
        awk '
{
    print$0
}
/^### List of Workloads:/ {
    exit
}' "$readme1" > "$readme1".wip
        distsvg="${readme1/README.md/dist.svg}"
        write_table "$(dirname "$readme1")" | tee -a "$readme1".wip | awk -v COLORS="$COLORS" -v CATEGORIES="$CATEGORIES" '
BEGIN{
  split(COLORS,colors)
  split(CATEGORIES,labels)
}
{
  j=0
  for(i=1;i<length(labels);i++)
    if ($2=="`"labels[i]"`") j=i
  if (j>0) values[j]=values[j]+1
}
END{
  total=0
  for(i=1;i<=length(labels);i++)
      total=total+values[i]

  radius = 30
  PI = 3.141592654
  circuit = 2.0 * PI * radius
  radius2 = radius * 2.0
  radius4 = radius2 * 2.0

  vbox_width = radius4 + 115 + 115
  label_height = 10

  print("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
  print("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" version=\"1.1\" xml:space=\"preserve\" width=\"" vbox_width "\" height=\"" radius4 "\" viewBox=\"0 0 " vbox_width " " radius4 "\">")

  offset = 0
  for(i=1;i<=length(labels);i++) {
    delta = values[i] / total * circuit
    _offset = 0 - offset
    print("<circle r=\"" radius "\" cx=\"" radius2 "\" cy=\"" radius2 "\" fill=\"transparent\" stroke=\"" colors[i] "\" stroke-width=\"" radius2 "\" stroke-dashoffset=\"" _offset "\" stroke-dasharray=\"" delta " " circuit "\"></circle>")
    offset = offset + delta

    label_yoffset=((i-1)%5)*label_height*1.8 + radius4/4 - 15
    label_xoffset=radius4+5+int((i-1)/5)*(radius4-15) + 5
    print("<rect x=\"" label_xoffset "\" y=\"" label_yoffset+label_height-label_height/2-1 "\" width=\"" 20*1.2 "\" height=\"" label_height+1 "\" fill=\"" colors[i] "\"></rect>")
    print("<text x=\"" label_xoffset "\" y=\"" label_yoffset+label_height*2-label_height/2 "\" font-size=\".8em\">" labels[i] " " int(values[i]/total*100+0.5) "%</text>")
  }
  print("<circle r=\"" radius "\" cx=\"" radius2 "\" cy=\"" radius2 "\" stroke=\"#000000\"></circle>")
  print("<text x=\"" radius2-18 "\" y=\"" radius2+8 "\" fill=\"#FFFFFF\" stroke=\"#FFFFFF\" font-size=\"1.6em\">" total "</text>")
  print("</svg>")
}' > "$distsvg"
        [ -z "$(grep -F dist.svg "$readme1".wip)" ] && rm -f "$distsvg"
        awk '
/^### List of Workloads:/ {
    l=1
}
/^>/ && l==1 {
    le=1
}
/^###/ && !/^### List of Workloads:/ && l==1 {
    le=1
}
le==1 {
    print$0
}' "$readme1" >> "$readme1".wip
        mv -f "$readme1".wip "$readme1"
    fi
done

grep -E '^[|]\s*[|]' "$BUILD_DIR"/README.unsorted 1>&2

