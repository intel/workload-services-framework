#!/bin/bash -xe

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
BUILD_DIR="$DIR/../_wltable"

format_name () {
    echo "${1/-/}" | sed 's/^[^:]*: *//' | sed 's/;.*//' | sed 's/and .*//' |  sed 's/(.*//' | sed 's/[ .]*$//' | tr -d '`[]' | sed 's|\(.*\), *\(.*\)|\2 \1|'
}

calc_nimages () {
    cd "$BUILD_DIR"
    for p in $(cat "$DIR"/../workload/platforms); do
        cmake -DPLATFORM=$p -DACCEPT_LICENSE=ALL -DREGISTRY=a -DBACKEND=cumulus -DCUMULUS_OPTIONS="--dry-run --docker-run" .. > /dev/null 2>&1
        make bom 2> /dev/null
    done | awk '
/^BOM of/ {
    p1=gensub(/\/.*/,"",1,$3)
}
/^# workload/ {
    w=$2
}
/^# image:/ {
    im[w][$3]=1
    pm[w][p1]=1
}
END {
    for(w in im) {
        pp=""
        for (p1 in pm[w])
            pp=pp" "p1
        print w" "length(im[w])pp
    }
}' > "$BUILD_DIR"/nimages.txt
}

calc_nnodes () {
    cd "$BUILD_DIR"
    for p in $(cat "$DIR"/../workload/platforms); do
        cmake -DPLATFORM=$p -DREGISTRY=a -DBACKEND=cumulus -DCUMULUS_OPTIONS="--dry-run --docker-run" -DBENCHMARK="$2" -DACCEPT_LICENSE=ALL .. > /dev/null 2>&1
        (   cd "${1/*\/workload/workload}/$2"
            ctest -j $(nproc) 2>/dev/null 1>&2 || true
            cat logs-*/cluster-config.yaml 2> /dev/null || true
            rm -rf logs-* > /dev/null 2>&1 || true
        ) 
    done | awk '
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
}' | sort -n
}

write_table () {
    echo "| Category | Workload | Platform | #Node | #IMG | Keywords |"
    echo "|:---|:---|:---|:--:|:--:|:--:|"

    for buildsh in "$1"/*/build.sh; do
        workload_dirname="$(dirname "$buildsh")"
        workload_dirname="${workload_dirname/*\//}"
        readme="${buildsh/build.sh/README.md}"
        if [ -r "$readme" ]; then
            section=0
            name=""
            category=""
            platform=""
            keywords=""
            while IFS= read line; do
                line="$(echo $line | sed 's/\r//')"
                case "$line" in 
                "### "*)
                    if [[ "$line" = *"Index Info"* ]] || [[ "$line" = *"Contact"* ]]; then
                        section=1
                    else
                        section=0
                    fi
                    ;;
                "- Name: "*)
                    if [ $section -eq 1 ]; then
                        name="\`$(echo "${line/- Name: /}" | sed -e 's/ *$//' -e 's/^ *//' | tr -d '`')\`"
                    fi
                    ;;
                "- Category: "*)
                    if [ $section -eq 1 ]; then
                        category="$(echo "${line/- Category: /}" | sed -e 's/ *$//' -e 's/^ *//')"
                    fi
                    ;;
                "- Keywords: "*)
                    if [ $section -eq 1 ]; then
                        keywords="$(echo "${line/- Keywords: /}" | tr 'a-z' 'A-Z' | sed -e 's/ *$//' -e 's/^ *//')"
                    fi    
                    ;;   
                esac
            done < "$readme"

            platform=" $(awk -v w="${1/*\/workload/workload}/$workload_dirname" '$1==w{$1="";$2="";print$0}' "$BUILD_DIR/nimages.txt") "
            platform="$(for p1 in $(cat "$DIR/../workload/platforms"); do
                            if [[ "$platform" = *" $p1 "* ]]; then
                                p2="${p1/ROME/RO}"
                                p2="${p2/MILAN/MI}"
                                p2="${p2/GRAVITON2/G2}"
                                p2="${p2/GRAVITON3/G3}"
                                echo '`'$p2'`'
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
            nimages="$(awk -v w="${1/*\/workload/workload}/$workload_dirname" '$1==w{print$2}' "$BUILD_DIR/nimages.txt")"
            nnodes="$(calc_nnodes "$1" "$workload_dirname" | tr '\n' '/')"
            echo "| $category | [$name]($workload_dirname) | $platform | ${nnodes%/} | $nimages | $keywords |"
        fi
    done | sort
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

for readme1 in "$DIR"/../workload/README.md; do
    for buildsh in "$(dirname "$readme1")"/*/build.sh; do
        chmod a+rx "$buildsh"
        chmod a+rx "${buildsh/build.sh/validate.sh}"
        chmod a+rx "${buildsh/build.sh/kpi.sh}"
    done
done

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
        write_table "$(dirname "$readme1")" | tee -a "$readme1".wip | awk '
BEGIN{
  split("#a73107 #e24b6e #16ade4 #ade416 #16e4b4 #2b5969 #e4c916",colors)
  split("DataServices ML/DL/AI HPC uServices Synthetic Networking Media",labels)
}
{
  for(i=1;i<=length(labels);i++)
    if ($2=="`"labels[i]"`") values[i]=values[i]+1
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

  vbox_width = radius4 + 100 + 10 + 5
  label_height = 10

  print("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
  print("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:svg=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" version=\"1.1\" xml:space=\"preserve\" width=\"" vbox_width "\" height=\"" radius4 "\" viewBox=\"0 0 " vbox_width " " radius4 "\">")

  offset = 0
  label_offset = label_height/2
  for(i=1;i<=length(labels);i++) {
    delta = values[i] / total * circuit
    _offset = 0 - offset
    print("<circle r=\"" radius "\" cx=\"" radius2 "\" cy=\"" radius2 "\" fill=\"transparent\" stroke=\"" colors[i] "\" stroke-width=\"" radius2 "\" stroke-dashoffset=\"" _offset "\" stroke-dasharray=\"" delta " " circuit "\"></circle>")
    offset = offset + delta

    print("<rect x=\"" radius4+5 "\" y=\"" label_offset+label_height-label_height/2-1 "\" width=\"" 20*1.2 "\" height=\"" label_height+1 "\" fill=\"" colors[i] "\"></rect>")
    print("<text x=\"" radius4+5 "\" y=\"" label_offset+label_height*2-label_height/2 "\" font-size=\".8em\">" labels[i] " " int(values[i]/total*100+0.5) "%</text>")
    label_offset=label_offset+label_height*1.5
  }
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
