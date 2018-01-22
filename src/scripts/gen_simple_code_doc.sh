#!/usr/bin/env bash

# Author: Michael Mitchell
version=0.5

###*** FUNCTIONS ***###

## Function to display program usage
function usage { 
    echo -e "The general purpose doc tool. VERSION: $version\n
    Usage: $0 -t [TITLE] -a [AUTHOR] -s [SOURCE CODE] -o [OUTPUT]
    \n\tWhere \"TITLE\" is the title of the generated document.
    \tWhere \"AUTHOR\" is the specified author.
    \tWhere SOURCE CODE is the origional source code to document.
    \tWhere OUTPUT is the output file to generate to.
    \n\tUse \"\" where necessary.\n";
}

###*** END FUNCTIONS ***###

###*** MAIN ***###

OPTERR=0 # Quite getopts

## Initialize to NULL so we can compare later if need be.
TITLE=NULL
AUTHOR=NULL
LANGUAGE=NULL
SOURCE=NULL
DOC=NULL

## Use getopts to parse the command line options
while getopts :ht:a:s:o: opt; do
    case $opt in
        t) ## Found title flag
            TITLE=$OPTARG 
            ;;
        a) ## Found author flag
            AUTHOR=$OPTARG 
            ;;
        s) ## Found source flag
            SOURCE=$OPTARG
            ;;
        o) ## Found doc flag
            DOC=$OPTARG
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

## Make sure TITLE, AUTHOR, SOURCE, and DOC are not NULL
case $TITLE in
    NULL)
        usage
        exit 1
        ;;
esac

case $AUTHOR in
    NULL)
        usage
        exit 1
        ;;
esac

case $SOURCE in
    NULL) 
        usage
        exit 1
        ;;
    *)
        if [[ $SOURCE == $(basename $SOURCE) ]]; then
            SOURCE=$(pwd)/$SOURCE
        fi
        ;;
esac

case $DOC in
    NULL) 
        usage
        exit 1
        ;;
    *)
        if [[ $DOC == $(basename $DOC) ]]; then
            DOC=$(pwd)/$DOC
        fi
        ;;
esac

## Determine the language for the syntax highlighting based on file extension
LANGUAGE=.$(echo $(basename $SOURCE) | sed -rn 's/(^[a-zA-Z0-9]*\.)//p')

## Create the markdown file to generate the PDF from
echo "---
title: $TITLE
author: $AUTHOR
geometry: margin=2cm
---

~~~ {$LANGUAGE .numberLines startFrom="1"}" >/tmp/tmpDoc.md

cat $SOURCE >>/tmp/tmpDoc.md

echo "~~~" >>/tmp/tmpDoc.md

## Generate the pdf from the markdown file.
pandoc -o $DOC /tmp/tmpDoc.md
