#!/usr/bin/env bash

## Functions
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

Info:
    This is a simple unflexible script to take a string message,
    encode that message using minimodem, pad that message 
    so that it fits within a designated stereo music track,
    then put the padded track into the LFE channel of the origional
    stereo music track resulting in a 2.1 channel audio track.

    Most quality audio players don't play audio channels unless
    you have the hardware and supported devices to play them
    so since most people do not have a dedicated LFE device or
    have configured their system properly to play it, this is a 
    interesting and simplistic way to make a stego question or 
    demonstration.

Written by Michael Mitchell"
}

function parseForNull {
    if [[ -z ${1} ]] ; then
        usage
        exit 1
    fi
}

function missingDependency {
    if [[ $1 -ne 1 ]]; then
        echo "Missing $2 as a dependency!"
        exit 1
    fi
}

## Variables
OPTERR=0 # Quite getopts
message=
musicFile=
outputFile=
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

## Test for deps
minimodem &>/dev/null
missingDependency $? "minimodem"

ffmpeg &>/dev/null
missingDependency $? "ffmpeg"

## Parse command line options
while getopts :hdm:f:o:r: opt; do
    case $opt in
        d) ## Found decode flag
            decode=true
            ;;
        m) ## Found message flag
            message="$OPTARG"
            ;;
        f) ## Found music file
            musicFile="$OPTARG"
            ;;
        o) ## Found output file
            outputFile="$OPTARG"
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

parseForNull ${musicFile}

## Depending on the users choice, test to make sure that the selected
## music track for encoding or decoding actually exists before proceding
if [[ ! -f $musicFile ]] ; then
    echo "$musicFile does not exist!"
    exit 1
fi

if [[ $decode == true ]]; then ## Decode 
    echo "Separating out the LFE track"
    ffmpeg -hide_banner -loglevel panic -i $musicFile -map_channel 0.0.2 $stegoTrack

    echo "Attempting to decode:"
    minimodem --rx -q -f $stegoTrack $rate

else  ## Encode
    parseForNull ${message}
    parseForNull ${outputFile}
    
    echo "Making stego temporary file"
    minimodem --tx -f $rawData $rate <<< $message
    
    if [[ $? -ne 0 ]]; then
        echo "Failed to encode data :( Try some different characters!"
        exit 1
    fi
    
    duration=$(ffmpeg -i $musicFile 2>&1 | grep Duration | awk '{print $2}' | head -c 8)
    hours=$(echo $duration | awk -F ':' '{print $1}')
    minutes=$(echo $duration | awk -F ':' '{print $2}')
    seconds=$(echo $duration | awk -F ':' '{print $3}')
    let "durationOfMedia = (hours * 60 * 60) + (minutes * 60) + seconds"
    echo "Duration of Media: $durationOfMedia"
    
    duration=$(ffmpeg -i $rawData 2>&1 | grep Duration | awk '{print $2}' | head -c 8)
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
    ffmpeg -hide_banner -loglevel panic -i $musicFile -i $paddedData -filter_complex "[0:0][1:0]amerge=inputs=2[audio]" -map "[audio]" $stegoTrack
    
    echo "Moving FC to LFE"
    ffmpeg -hide_banner -loglevel panic -i $stegoTrack -map_channel 0.0.0 -map_channel 0.0.1 -map_channel 0.0.2 $outputFile
fi

rm $rawData $silenceWav $paddedData $stegoTrack &>/dev/null

echo -e "\nDONE!"

exit 0

