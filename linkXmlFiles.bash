#!/bin/bash

################################################################################
# File: linkXmlFiles.bash
#
# Description: This bash shell script creates hard links in the directory
# dest_dir that link to the num_files largest XML files containing the MEDLINE
# corpus in the directory specified by source_dir.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

prog="linkXmlFiles.bash"
usage="$prog source_dir dest_dir num_files"

if [[ $# -ne 3 ]]; then
   echo "USAGE: $usage" 1>&2
   exit 1
fi

SOURCE_DIR=$1
DEST_DIR=$2
NUM_FILES=$3

unalias ls >& /dev/null

if [[ -e $DEST_DIR ]]; then
   rm -r $DEST_DIR
fi

mkdir -p $DEST_DIR

# Sort files largest to smallest and link to the NUM_FILES
# largest ones
sorted_files=`ls -1 -S $SOURCE_DIR | head -n $NUM_FILES` 

for f in $sorted_files; do
   echo "Linking file $f"

   # The python script that reads these files wants hard links
   ln $SOURCE_DIR/$f $DEST_DIR
done
