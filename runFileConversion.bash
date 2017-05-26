#!/bin/bash

################################################################################
# File: runFileConversion.bash
#
# Description: This bash shell script converts to python pickle format the XML
# files hardlinked by the linkXmlFiles.bash script.  The destination directory
# of the pickle files must be defined in the default.cfg config file in the
# medline python library under the temp.data.directory configuration parameter.
# This script is intended to be executed from the same directory as where the
# top-level directory of the medline python library is located.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

prog="runFileConversion.bash"
usage="$prog xml_file_dir"

if [[ $# -ne 1 ]]; then
   echo "$usage"
   exit 1
fi

XML_FILE_DIR=$1

export PYTHONPATH=$PBS_O_WORKDIR:$PYTHONPATH

echo "-------------------------------"
echo "PBS environment "
echo "-------------------------------"
echo "PBS_O_WORKDIR: " $PBS_O_WORKDIR
echo "PBS_O_HOST   : " $PBS_O_HOST
echo "-------------------------------"
echo "Script arguments"
echo "-------------------------------"
echo ${XML_FILE_DIR}
echo "-------------------------------"
echo "Running..."

cd $PBS_O_WORKDIR

# Switch to python virtual environment
source ./pubmed/bin/activate

python ./medline/data/load/save_to_temp_files.py ${XML_FILE_DIR} -i xml

exit 0
