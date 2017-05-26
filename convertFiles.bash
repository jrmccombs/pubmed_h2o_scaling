#!/bin/bash
#PBS -l nodes=1:ppn=16,walltime=01:15:00
#PBS -N pickle_em
#PBS -j oe
#ZPBS -q debug
#ZPBS -m be
#ZPBS -M jmccombs@iu.edu

cd $PBS_O_WORKDIR

# Set raw_xml_directory to the directory populated by the linkXmlFiles.bash script
raw_xml_directory=/N/dc2/scratch/jmccombs/medline/raw/100files/
temp_data_directory=/N/dc2/scratch/jmccombs/medline/pickled/100files

# Create the temp.data.directory directory specified in the pubmed default.cfg file
if [[ -e $temp_data_directory ]]; then
   rm -r -f $temp_data_directory
fi

mkdir -p $temp_data_directory

# Convert the raw XML files and store the resulting pickled files in the
# directory given in $temp_data_directory.
./runFileConversion.bash $raw_xml_directory

exit $?
