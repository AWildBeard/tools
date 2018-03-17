#!/usr/bin/env bash

## Author: Michael Mitchell
version=1.0

###*** FUNCTIONS ***###

## Function to cleanup leftover files.
function cleanup { rm -rf $backupName.tgz timestamp.txt /tmp/newTimes.txt &>/dev/null; }

## Function to do the actual backups.
function backup {
    ## Change to the directory where we will store the backup file
    cd $storageDir
    ## Create the backup of the contents
    tar -czf $backupName.tgz $backupDir 2>/dev/null 1>/dev/null || { 
        echo "Failed to backup $backupDir!"
        exit 1
    }
    ## Create a timestamp log for the backup we just made.
    cat /tmp/newTimes.txt > timestamp.txt
    ## Archive the backup and the timestamp log together.
    tar -cf $backupName.tar timestamp.txt $backupName.tgz
    cleanup ## Always cleanup our messes :D
}

## Function to display program usage
function usage { 
    echo -e "The general purpose smart backup tool. VERSION: $version\n
    Usage: $(basename $0) -b [BACKUP DIRECTORY] -s [STORAGE DIRECTORY]
    \n\tWhere BACKUP DIRECTORY is the directory to create a backup of.
    \tWhere STORAGE DIRECTORY is the directory to put the backup in.\n";
}

###*** END FUNCTIONS ***###

###*** MAIN ***###

OPTERR=0 # Quite getopts

## Initialize to NULL so we can compare later if need be.
storageDir=NULL ## Directory to store the backup in
backupDir=NULL  ## Directory to backup

## Use getopts to parse the command line options
while getopts :hb:s: opt; do
    case $opt in
        b) ## Found backup flag
            backupDir=$OPTARG ## Assign the backup flags arg to backupDir
            ;;
        s) ## Found storage flag
            storageDir=$OPTARG ## Assign the storage flags arg to storageDir
            ;;
        h) ## Found help flag
            usage
            exit 0
            ;;
        :) ## Found a flag that should have a argument but doesn't
            echo "Flag -$OPTARG requires an argumet!"
            usage
            exit 1
            ;;
        \?) ## Found something that shouldn't be there.
            usage
            exit 1
            ;;
    esac
done

## Check to make sure $storageDir and $backupDir are not NULL
case $storageDir in
    NULL) ## Never found the storage flag :(
        usage
        exit 1
        ;;
    *)
        ## Make sure $storageDir is not an implicit path.
        storageDir="$(echo $storageDir | sed 's:/$::g')" ## Remove trailing /
        if [[ $storageDir == $(basename $storageDir) ]]; then
            ## If it is, just do the conversion for the lazy sods.
            storageDir=$(pwd)/$storageDir
        fi
        ;;
esac

case $backupDir in
    NULL) ## Never found the storage flag :(
        usage
        exit 1
        ;;
    *)
        ## Make sure $backupDir is not an implicit path.
        backupDir="$(echo $backupDir | sed 's:/$::g')" ## Remove trailing /
        if [[ $backupDir == $(basename $backupDir) ]]; then
            ## If it is, just do the conversion for the lazy sods.
            backupDir=$(pwd)/$backupDir
        fi
        ;;
esac

## Determine the name for the backup file from the directory being backed up
backupName=$(basename $backupDir) ## The name to name the backup file

## Get the timestamp data of the directory to backup and its 
## subdirectories so we can compare them to any previous backups 
## or for creating a fresh backup.
find $backupDir -type d -printf '%f %c\n' > /tmp/newTimes.txt 2>&1 || { 
    echo "Failed to find $backupDir!"
    exit 1
}

## Decision logic to perform a backup.

## Move to where a previous backup could be stored. 
cd $storageDir &>/dev/null || { 
    echo "Failed to find $storageDir!"
    exit 1
}

if [[ -f $backupName.tar ]]; then ## a previous backup exists
    ## Compare timestamps of the directory to backup with the previous backups timestamp log.
    tar -xf $backupName.tar ## Extract the archive where the backups timestamp log is stored.

    ## Compare timestamp logs of the directory to backup with the previous backups timestamp log.
    if [[ $(cat /tmp/newTimes.txt) != $(cat timestamp.txt) ]]; then
        ## Time stamp log on backup does not match our 
        ## generated time stamp log (which means something has changed)
        ## so we should create a backup of those changes.
        backup
    else 
        ## Time stamp on backup does match our potential directories time stamp log
        ## so we do not need to create another backup of the exact same information.
        ## Do not backup again.
        cleanup
    fi

else ## previous backup does not exist... create one.
    backup
fi

###*** END MAIN ***###

