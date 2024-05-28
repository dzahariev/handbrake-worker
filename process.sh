#! /bin/bash
TASKS="/tasks"
INPUT="/input"
OUTPUT="/output"
KIND="handbrake"

# Look in soecified folder for tasks that are of predefined kind and are not done 
get_next_task(){
    local TASKS_FOLDER_NAME=${1}
    local TASKS_KIND=${2}
    
    for FULL_FILE_NAME in "${TASKS_FOLDER_NAME}"/*; do
        FILE_NAME="$(basename "$FULL_FILE_NAME")"
        EXTENSION="${FILE_NAME##*.}"
        if  [[ "${EXTENSION}" == "json" ]]; then
            CT_KIND=$(cat ${FULL_FILE_NAME} | jq -r .kind)
            STATUS=$(cat ${FULL_FILE_NAME} | jq -r .status)
            if  [[ "${CT_KIND}" == "${TASKS_KIND}" ]]; then
                if  [[ ! "${STATUS}" == "done" ]]; then
                    echo "${FULL_FILE_NAME}"
                fi
            fi
        fi
    done
}

update_task(){
    local TASK=${1}
    local LOG=${2}
    sleep 10 

    PROGRESSING=true
    while ${PROGRESSING} 
    do
        CURRENT_STATS=$(tail -17 ${LOG})
        if  [[ ${CURRENT_STATS} = Progress* ]] ; then
            JSON_STATS=$(echo ${CURRENT_STATS} | cut -d ' ' -f 2- )
            PROGRESS=$(echo ${JSON_STATS} | jq -r .Working.Progress)
            HR_PROGRESS=$(echo ${PROGRESS} | bc -l | xargs printf "%.2f")
            PROGRESS_PRECENT=$( bc -l <<<"100*${HR_PROGRESS}" )
            HR_PROGRESS_PRECENT=$(echo ${PROGRESS_PRECENT} | bc -l | xargs printf "%.0f")
            TASK_CONTENT=$(cat ${TASK}) 
            TASK_FILE_UPDATED_CONTENT=$(echo -E ${TASK_CONTENT} | jq --arg vprogress ${HR_PROGRESS_PRECENT} '.progress = $vprogress') 
            TASK_FILE_UPDATED2_CONTENT=$(echo -E ${TASK_FILE_UPDATED_CONTENT} | jq '.status = "working"')  
            echo -E "${TASK_FILE_UPDATED2_CONTENT}" > ${TASK}
        else
            CURRENT_STATS=$(tail -8 ${LOG})
            if  [[ ${CURRENT_STATS} = Progress* ]] ; then
                JSON_STATS=$(echo ${CURRENT_STATS} | cut -d ' ' -f 2- )
                STATE=$(echo ${JSON_STATS} | jq -r .State)

                TASK_CONTENT=$(cat $TASK) 
                TASK_FILE_UPDATED_CONTENT=$(echo -E ${TASK_CONTENT} | jq '.progress = "100"')  
                TASK_FILE_UPDATED2_CONTENT=$(echo -E ${TASK_FILE_UPDATED_CONTENT} | jq '.status = "done"')  
                echo -E "${TASK_FILE_UPDATED2_CONTENT}" > ${TASK}
                rm -f ${LOG}
                PROGRESSING=false
            else
                echo "Unknow - ${CURRENT_STATS}"
            fi
        fi    
        sleep 10 
    done
}

echo "Starting to watch the folder with tasks: ${TASKS}"

while true
do
    read -r FILE_TO_PROCESS <<< "$( get_next_task ${TASKS} ${KIND} )"
    echo "Filename: ${FILE_TO_PROCESS}"

    if [ -e "${FILE_TO_PROCESS}" ]; then
        SOURCE=$(cat ${FILE_TO_PROCESS} | jq -r .source)
        ID=$(cat ${FILE_TO_PROCESS} | jq -r .id)
        PRESET=$(cat ${FILE_TO_PROCESS} | jq -r .preset)
        echo "Processing ${SOURCE} with preset ${PRESET} ..."
        
        HandBrakeCLI --preset-import-file /app/${PRESET}.json -Z ${PRESET} -i ${INPUT}/${SOURCE} -o ${OUTPUT}/${SOURCE%%.*}.mp4 --json > ${ID}_encoding.log &
        update_task ${FILE_TO_PROCESS} ${ID}_encoding.log &
        wait
    fi 

    sleep 10
done