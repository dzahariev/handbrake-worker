#! /bin/bash
TASKS_LOCATION="/tasks"
INPUT_LOCATION="/input"
OUTPUT_LOCATION="/output"
TASKS_KIND="handbrake"

get_next_task(){
    local tasksfolder=${1}
    local taskskind=${2}

    for filenamewithpath in "${tasksfolder}"/*; do
        filename="$(basename "$filenamewithpath")"
        extension="${filename##*.}"
        if  [[ "${extension}" == "json" ]]; then
            taskkind=$(cat ${filenamewithpath} | jq -r .kind)
            taskstatus=$(cat ${filenamewithpath} | jq -r .status)
            if  [[ "${taskkind}" == "${taskskind}" ]]; then
                if  [[ ! "${taskstatus}" == "done" ]]; then
                    echo "${filenamewithpath}"
                fi
            fi
        fi
    done
}

is_valid_json(){
    [[ $(echo ${1} | jq -e . &>/dev/null; echo $?) -eq 0 ]] && echo "true" || echo "false"
}

get_conversion_status(){
    local reportjson=${1}

    state="$(echo ${reportjson} | jq -r '.State')"
    if  [[ $state == "WORKDONE" ]]; then
        echo "done"
    else 
        if  [[ $state == "WORKING" ]]; then
            echo "working"
        else
            echo "unknown"
        fi
    fi
}

get_conversion_progress(){
    local reportjson=${1}

    state="$(echo ${reportjson} | jq -r '.State')"
    if  [[ $state == "WORKDONE" ]]; then
        echo "100"
    else 
        if  [[ $state == "WORKING" ]]; then
            progressraw=$(echo ${1} | jq -r .Working.Progress)
            progressfloat=$(echo ${progressraw} | bc -l | xargs printf "%.2f")
            progressprcfloat=$( bc -l <<<"100*${progressfloat}" )
            progress_int=$(echo ${progressprcfloat} | bc -l | xargs printf "%.0f")
            echo "$progress_int"
        else
            echo "0"
        fi
    fi
}

update_task(){
    local taskfilename=${1}
    local taskstatus=${2}
    local taskprogress=${3}

    taskjson=$(cat ${taskfilename}) 
    taskjsonupdstatus=$(echo -E $taskjson | jq --arg vstatus $taskstatus '.status = $vstatus') 
    taskjsonupd=$(echo -E $taskjsonupdstatus | jq --arg vprogress $taskprogress '.progress = $vprogress') 
    echo -E "$taskjsonupd" > $taskfilename
}

process_exists(){
    pgrep -x ${1} >/dev/null && echo "true" || echo "false"
}

monitor_task(){
    local taskfilename=${1}
    local logfilename=${2}

    sleep 10 
    progressing=true
    while $progressing 
    do
        str=$(tail -40 $logfilename)
        delimiter="Progress: "
        array=()
        while [ "$str" ]; do
            substring="${str%%"$delimiter"*}" 
            [ -z "$substring" ] && str="${str#"$delimiter"}" && continue
            array+=( "$substring" )
            str="${str:${#substring}}"
            [ "$str" == "$delimiter" ] && break
        done
        declare -p array 

        lastreport=""
        for line in "${array[@]}"
        do
            flatline=$(echo -n $line)
            valid=$(is_valid_json  "$flatline")
            if  [[ "$valid" == "true" ]]; then
                lastreport=$flatline
            fi
        done

        handbrakeprocessexists=$(process_exists "HandBrakeCLI")
        conversionstatus=$(get_conversion_status "$lastreport")
        conversionprogress=$(get_conversion_progress "$lastreport")

        if  [[ $conversionstatus == "done" ]]; then
            update_task $taskfilename $conversionstatus $conversionprogress 
            rm -f $logfilename
            progressing=false
        else
            if  [[ $conversionstatus == "working" ]]; then
                update_task $taskfilename $conversionstatus $conversionprogress 
            else
                echo "Unknow: $lastreport"
            fi
        fi

        if  [[ $handbrakeprocessexists == "true" ]]; then
            echo "Process HandBrakeCLI is started. Continue monitoring of the task."
        else
            echo "Process HandBrakeCLI is not started. Stoping monitoring of the task."
            rm -f $logfilename
            progressing=false
        fi

        sleep 10 
    done
}

echo "Starting to watch the folder with tasks: $TASKS_LOCATION"

while true
do
    read -r TASK_TO_PROCESS <<< "$( get_next_task $TASKS_LOCATION $TASKS_KIND )"

    if [ -e "$TASK_TO_PROCESS" ]; then
        ID=$(cat $TASK_TO_PROCESS | jq -r .id)
        SOURCE=$(cat $TASK_TO_PROCESS | jq -r .source)
        PRESET=$(cat $TASK_TO_PROCESS | jq -r .preset)
        echo "Converting $SOURCE using preset $PRESET ..."
        HandBrakeCLI --encoder vaapi_h264 --vaapi-device /dev/dri/renderD128 --preset-import-file /app/$PRESET.json -Z $PRESET -i $INPUT_LOCATION/$SOURCE -o $OUTPUT_LOCATION/${SOURCE%.*}.mp4 --json > ${ID}_enc.log &
        monitor_task $TASK_TO_PROCESS ${ID}_enc.log &
        wait
    else
        echo "There is no task for conversion in queue. Sleeping ..."
    fi

    sleep 10
done