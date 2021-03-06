#!/bin/bash

################################################################################
# File: prepareScalingTests.bash
#
# Description: This bash shell script generates the directories in which the
# scalability performance tests can be executed for each desired combination of
# number of H2O nodes and number of threads per node to be tested.  The
# pickle_base_dir directory indicates where all of the preprocessed data sets
# are.  The test_set argument names the top-level directory in which the
# subdirectories for each performance test will be stored.  It also names the
# subdirectory where the pickle files containing the preprocessed corpus data
# are stored (see linkXmlFiles.bash and runFileConversion.bash).  The numbers of
# nodes, numbers of threads, and numbers of clusters to be discovered are
# specified with num_nodes, num_threads, and num_clusters, array arguments
# respectively.  Each subdirectory corresponding to a particular combination of
# number of nodes and number of threads to be tested is named according to the
# format N_T_C where N is the number of H2O nodes, T is the number of H2O worker
# threads per node, and C is the number of clusters to be discovered.
#    The default_port argument is the default port assigned the H2O processes
# so that they may communicate during distributed machine learning operations.
# A configuration file is autogenerated in python config library format for each
# performance test to be conducted.
#
# Arguments:
#   pickle_base_dir - The base directory containing subdirectories which
#     contain the pickle data files (the preprocessed data) on which to perform
#     a scalability study.
#
#   test_set - the name of test data set on which to perform a scalability
#     study.  The value must be identical to a subdirectory in pickle_base_dir.
#     It also names the top level directory where output log files and standard
#     output and error files will be stored from the batch job.
#
#   default_port - the default port H2O will communicate on
#
#   num_nodes - an array of numbers of nodes to be tested with; the array must
#     be specified in double digits.
#     Example: "01 02 03 04 08 16" for testing with 1, 2, 3, 4, 8, and 16 nodes.
#
#   num_threads - an array of numbers of threads to be tested; the array must be
#     specified in double digits.
#     Example: "01 02 04 08 16" for testing with 1, 2, 4, 8, and 16 nodes. 
#
#   num_clusters - an array of numbers of clusters to be tested; the array must
#     be specified in double digits.
#     Example: "01000 02000 04000 08000 15000" for testing with 1000, 2000,
#     4000, 8000, and 15000 nodes. 
# 
# NOTE: The port number and log file names written into the config files
# generated by this script can be overridden by the scaleTestH2O.bash and
# pubmed.py scripts, enabling concurrent performance trials that each
# utilize different port numbers and output log files without conflict.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

prog="prepareScalingTests.bash"
USAGE="USAGE: $prog pickle_base_dir test_set default_port num_nodes num_threads num_clusters"

function generate_config {
   if [[ -e $1 ]]; then
      rm $1
   fi

   echo "[input]" >> $1
   echo "input.file.type = .txt,.xml" >> $1
   echo "input.filters = none" >> $1
   echo "abstracts.record.separator = SEGMENTBREAK" >> $1
   echo "abstracts.parser.content.index = 4" >> $1
   echo "abstracts.parser.permalink.index = -2" >> $1
   echo "abstracts.parser.title.index = 1" >> $1
   echo "temp.data.directory = ${2}" >> $1
   echo >> $1
   echo "[clustering]" >> $1
   echo "clusters.count = ${6}" >> $1
   echo "iterations.count = 30" >> $1
   echo "init.count = 3" >> $1
   echo "kmeans.batch.size = 50000" >> $1
   echo "cluster.terms.count = 20" >> $1
   echo "verbosity = 1" >> $1
   echo "init.process.count = 4" >> $1
   echo >> $1
   echo "[feature-extraction]" >> $1
   echo "document.frequency.min = 0.05" >> $1
   echo "document.frequency.max = 0.7" >> $1
   echo "vectorizer = tfidf" >> $1
   echo "vectorizer.input.type = file" >> $1
   echo "vectorizer.features.avail = 0" >> $1
   echo "features.dimension = 100" >> $1
   echo "normalization = l1" >> $1
   echo "features.pickled.files.directory = ${3}" >> $1
   echo >> $1
   echo "[output]" >> $1
   echo "permalink.base.url = https://www.ncbi.nlm.nih.gov/pubmed/" >> $1
   echo "permalink.base.search.url = https://www.ncbi.nlm.nih.gov/pubmed/?term=" >> $1
   echo >> $1
   echo "[logging]" >> $1
   echo "logging.directory = logs/" >> $1
   echo "log.filename = ${4}.log" >> $1
   echo >> $1
   echo "[framework]" >> $1
   echo "h2o.server.url = http://localhost:${5}" >> $1
}
   

if [[ $# -ne 6 ]]; then
  echo "$USAGE"
  exit 1
fi

PICKLE_BASE_DIR=$1
TEST_SET=$2
DEFAULT_PORT=$3
NUM_NODES=$4
NUM_THREADS=$5
NUM_CLUSTERS=$6

mkdir -p $TEST_SET
cd $TEST_SET

preprocessed_dir="${PICKLE_BASE_DIR}/${TEST_SET}/"
feature_extraction_dir="/tmp/medline/checkpoint/${TEST_SET}/"

for n in $NUM_NODES; do
   for t in $NUM_THREADS; do
      for c in $NUM_CLUSTERS; do
         test_id=${n}_${t}_${c}
         config_file=config_${test_id}.cfg

         mkdir -p $test_id
         cd $test_id
   
         mkdir -p ./logs

         generate_config $config_file $preprocessed_dir $feature_extraction_dir $test_id $DEFAULT_PORT $c
         cd ..
      done   
   done
done

exit 0
