#!/usr/bin/env bash

## Script

function usage {
    echo -e "Usage:
    -d 
        turn decode mode on. This makes the -m and -o flags useless,
        attempts to pull the lfe track out of musicFile, and decode
        the message if there is one there.
    -m [message] 
        where message is a string
    -f [musicFile]
        where musicFile is the file to hide or decode the message.
    -o [outputFile]
        where outputFile is the file to store the result
    -r [rate]
        optionally set a rate to encode and decode with minimodem.
        Default 300
\nWritten by Michael Mitchell"
}

function parseForNull {
    if [[ -z ${1} ]] ; then
        usage
        exit 1
    fi
}

OPTERR=0 # Quite getopts
args=(message musicFile outputFile)
durationOfMedia=
durationOfStego=
durationOfSilence=
decode=false
rate=300

## Temporary files
silenceWav=/tmp/silence.wav
rawData=/tmp/data.wav
paddedData=/tmp/paddedData.wav
stegoTrack=/tmp/stego.wav

for i in ${!args[@]}; do
    args[$i]=
done

while getopts :hdm:f:o:r: opt; do
    case $opt in
        d) ## Found decode flag
            decode=true
            ;;
        m) ## Found stego file
            args[0]="$OPTARG"
            ;;
        f) ## Found music file
            args[1]="$OPTARG"
            ;;
        o) ## Found output file
            args[2]="$OPTARG"
            ;;
        r) ## Found rate flag
            rate=$OPTARG
            ;;
        h) ## Found help flag
            usage
            exit 0
            ;;
        :) ## Missing an argument
            echo "Flag -$OPTARG requires an argument!"
            exit 1
            ;;
        \?) ## Found something wrong
            usage
            exit 1
            ;;
    esac
done

if [[ $decode == true ]]; then
    if [[ -z ${args[1]} ]]; then
        usage
        exit 1
    fi 

    echo "Separating out the LFE track"
    ffmpeg -hide_banner -loglevel panic -i ${args[1]} -map_channel 0.0.2 $stegoTrack

    echo "Attempting to decode:"
    minimodem --rx -q -f $stegoTrack $rate

else 
    for i in ${!args[@]} ; do
        parseForNull ${args[$i]}
    done 
    
    if [[ ! -f ${args[1]} ]] ; then
        echo "${args[1]} does not exist!"
        exit 1
    fi
    
    echo "Making stego temporary file"
    minimodem --tx -f $rawData $rate <<< ${args[0]}
    
    if [[ $? -ne 0 ]]; then 
        echo "Failed to encode data :( Try some different characters!"
        exit 1
    fi
    
    duration=$(ffmpeg -i ${args[1]} 2>&1 | grep Duration | awk '{print $2}' | head -c 8)
    hours=$(echo $duration | awk -F ':' '{print $1}')
    minutes=$(echo $duration | awk -F ':' '{print $2}')
    seconds=$(echo $duration | awk -F ':' '{print $3}')
    let "durationOfMedia = (hours * 60 * 60) + (minutes * 60) + seconds"
    echo "Duration of Media: $durationOfMedia"
    
    duration=$(ffmpeg -i /tmp/tmp.wav 2>&1 | grep Duration | awk '{print $2}' | head -c 8)
    hours=$(echo $duration | awk -F ':' '{print $1}')
    minutes=$(echo $duration | awk -F ':' '{print $2}')
    seconds=$(echo $duration | awk -F ':' '{print $3}')
    let "durationOfStego = (hours * 60 * 60) + (minutes * 60) + seconds"
    echo "Duration of Stego: $durationOfStego (Don't be suprised if this is a very small number)"
    
    let "durationOfSilence = (durationOfMedia - durationOfStego) / 2"
    echo "Duration of Silence: $durationOfSilence"
    
    echo "Creating silent pad for center track"
    ffmpeg -hide_banner -loglevel panic -f lavfi -i "anullsrc=channel_layout=mono" -t $durationOfSilence $silenceWav
    
    echo "Creating center track"
    ffmpeg -hide_banner -loglevel panic -i $silenceWav -i $rawData -i $silenceWav -filter_complex "[0:0][1:0][2:0]concat=n=3:v=0:a=1[audio]" -map "[audio]" $paddedData
    
    echo "Creating stego file"
    ffmpeg -hide_banner -loglevel panic -i ${args[1]} -i $paddedData -filter_complex "[0:0][1:0]amerge=inputs=2[audio]" -map "[audio]" $stegoTrack
    
    echo "Moving FC to LFE"
    ffmpeg -hide_banner -loglevel panic -i $stegoTrack -map_channel 0.0.0 -map_channel 0.0.1 -map_channel 0.0.2 ${args[2]}
fi

rm $rawData $silenceWav $paddedData $stegoTrack &>/dev/null

echo -e "\nDONE!"

