#!/usr/bin/env python3.6

# This is a small python script that runs a command when detecting a file
# has changed. My use case is to use it to compile a pandoc markdown into
# a pdf for me.

##** Config **##

sources_root = "src/"
build_command = "pandoc -o build/gpg.pdf --from markdown --pdf-engine=xelatex --highlight-style=breezeDark src/md/gpg.md"

##** Program **##

from os import walk
from os.path import join, getmtime
from time import ctime, sleep
from sys import exit, argv
import subprocess

##** Functions **##

def build(command):
    print("Executing Build...\n")
    process_handler = subprocess.run(command, stdout=subprocess.PIPE)
    stdout = process_handler.stdout.decode("UTF-8").rstrip()

    print(f"{stdout}\n")

    if not (process_handler.returncode == 0):
        print("Build Failed!\n")
        exit(process_handler.returncode)
    else:
        print("Build Finished!\n")

def generateSourcesTable():
    # Generate the last modified times.
    files = dict()

    fileGett = walk(sources_root)
    for dirpath, dirnames, filenames in fileGett:
        for fileName in filenames:
            fileNameAndPath = join(dirpath, fileName)
            files[fileNameAndPath] = ctime(getmtime(fileNameAndPath))

    return files

##** Main **##

continuous = False

if len(argv) == 2:
    if argv[1] == '-c':
        continuous = True
    else:
        print("Usage:\n\t%s [-c]\n\t\tWhere -c will continuously build on the script\n\t\tdetecting a file has changed" % argv[0])
        print("\n\tYou can configure where the script looks for file changes by\n\topening the script and changing the sources_root value")
        exit(0)

build_command = build_command.split()
build(build_command) # Build 

# Run loop to continually check if any of the files have been changed.
if continuous:
    files = generateSourcesTable() # dictionary of files and modified times.

    while True:
        sleep(1)

        newFiles = generateSourcesTable() 
        if not (files == newFiles):
            build(build_command) # Build 
            files = newFiles

##** End Main **##
