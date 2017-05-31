#!/bin/bash
#PBS -l nodes=1:ppn=16,walltime=00:10:00
#PBS -N TESTID_N_T_C
#PBS -j oe
#PBS -m be
#PBS -M jmccombs@iu.edu
#ZPBS -q debug

################################################################################
# File: scaleTestH2O.bash
#
# Description: This bash shell script is the PBS job submission script for
# running a performance trial for one combination of number of nodes and number
# of threads per node.  The script attempts to find an available set of ports on
# which H2O can run on each host allocated to the PBS job.   Once H2O processes
# have been instantiated on each host, the python clustering script is executed
# on the primary host running this script.  After the input data is read in, it
# is distributed to the H2O processes on each H2O host and the distributed
# clustering computation is performed.  The script must be called with the
# -N qsub option defining a job name with the format {testId}_{N}_{T}_{C} where
# testId is the name assigned to the group of corpus files with which the
# performance tests are being conducted (see runFileConversion.bash and
# prepareScalingTests.bash), N is the number of H2O nodes, T is the number
# of worker threads per H2O node, and C is the number of clusters to discover in
# the data set.  The -l PBS argument must be specified with the number of H2O
# nodes; the processors per node can be larger than or equal to the number of
# worker threads, but not less.
#    General PBS standard output and error messages are written to a job output
# file named using the format {testId}_N_T_C.o{jobId} where testId is the name
# assigned to the group of corpus files with which the performance test are
# being conducted; N, T, and C are as describe above; and jobId is the PBS
# numeric job ID assigned by PBS.  Output from H2O processes are in
# files named according to the format h2o_{hostName}_{pbsJobId}.log, where
# hostName is the name of the host an H2O process is running on, and pbsJobId
# is the job ID assigned to the environment variable $PBS_JOBID (often a
# concatenation of jobId and .m2).  Log files written by the python clustering
# script are written to the "logs" subdirectory (or other directory specified in
# the medline configuration file associated with the performance trial) and are
# named according to the format {pbsJobId}.log.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

# The ports in the specified port ranges will be probed on each node allocated
# to the batch job until available ports are located for each H2O server to
# use.
PORT_RANGE_START=54000
PORT_RANGE_END=65534

# Change this to the location of your h2o jar file
H2O_JAR=${HOME}/h2o-3.10.3.4/h2o.jar

# Change this to the location of your pubmed directory where
# the pubmed python package directory exists and the
# scalability studies are.  It should be where this script
# file is.
SOURCE_DIR=${HOME}/pubmed-medline-master

# For some reason, PBS sometimes does not set the
# path or it sets it incorrectly.  Hard code it.
PATH=/usr/local/bin:/bin:/usr/bin

# Set the python path for your system.
export PYTHONPATH=${HOME}/pubmed-medline-master:${PYTHONPATH}

# Function for retrieving allocated ports on remote hosts
function check_remote_port_status {
   ssh $1 "netstat -tulen | grep $2 | grep -i listen" > /dev/null 2>&1 
}

# Get the test name prefix
test_set=${PBS_JOBNAME%%_*}
# Get the number of input files
num_files=${test_set%%"files"}
# Compute the number of documents -- 30000 per file
num_docs=$(($num_files*30000))
# Get the number of nodes, threads, and clusters
test_id=${PBS_JOBNAME#*_}
# Get the number of nodes
num_nodes=${test_id%%_*}
# Trim off the number of nodes
test_id_clipped=${test_id#*_}
# Get the number of threads
num_threads=${test_id_clipped%%_*}
# Set host and ip file names
host_file=hostfile_${PBS_JOBID}
ip_file=ipfile_${PBS_JOBID}

FEATURE_EXTRACTION_DIR=/tmp/medline/checkpoint/${test_set}

echo "-------------------------------"
echo "H2O cluster test "
echo "-------------------------------"
echo "PBS environment "
echo "-------------------------------"
echo "PBS_O_WORKDIR    : " $PBS_O_WORKDIR
echo "PBS_O_HOST       : " $PBS_O_HOST
echo "PBS_JOBNAME      : " $PBS_JOBNAME
echo "PATH             : " $PATH 
echo "PORT_RANGE_START : " $PORT_RANGE_START
echo "H2O_JAR          : " $H2O_JAR
echo "test_id          : " $test_id
echo "num_nodes        : " $num_nodes
echo "num_threads      : " $num_threads
echo "host_file        : " $host_file
echo "ip_file          : " $ip_file
echo "-------------------------------"
echo "Running..."

cd $PBS_O_WORKDIR

if [[ -e $FEATURE_EXTRACTION_DIR ]]; then
   rm -r -f $FEATURE_EXTRACTION_DIR
fi

mkdir -p $FEATURE_EXTRACTION_DIR

if [[ $? -eq 127 ]]; then
   echo "ERROR: mkdir command not found" 1>&2
   exit 1
fi

# Switch to python virtual environment
source ../../pubmed/bin/activate

if [ -e ${host_file} ]; then
  rm -f ${host_file}
fi

if [ -e ${ip_file} ]; then
  rm -f ${ip_file}
fi

cat $PBS_NODEFILE | uniq | awk '{print $0}' > ${host_file}

echo 
echo "--------------------------"
echo "Computing port assignments"
echo "--------------------------"
full_host_name=`hostname`

# Build IP file
while read h; do
   # Get the IP address of the host in the host file
   node_ip_address=`nslookup $h | awk '/^Address: / { print $2 ; exit }'`
   echo "Computing port number to H2O host ${h} with IP ${node_ip_address}..."
   port_number=$PORT_RANGE_START
   next_port_number=$(($port_number+1))
   
   # Search for a free port on the host
   while [[ $port_number -le $PORT_RANGE_END ]]; do
      port_statuses=`ssh -n $h 'netstat -tulen' 2>/dev/null` 
      ssh_return=$?

      if [[ $ssh_return -eq 255 ]]; then
         echo "ERROR: ssh could not access host $h" 1>&2
         exit 1
      fi         

      if [[ $ssh_return -ne 0 ]]; then
         echo "ERROR: Could not get netstat information on host $h" 1>&2
         exit 1
      fi

      # An H2O host needs to acquire two contiguous ports.  Check
      # that the two ports satisify this condition.
      if [[ $port_statuses =~ ":$port_number" ]]; then
         echo "Port $port_number is not available on host $h" 
      else
         if [[ $port_statuses =~ ":$next_port_number" ]]; then
            echo "Port $next_port_number is not available on host $h" 
         else
            echo "Adding ${node_ip_address}:${port_number} to ipfile"
            echo "${node_ip_address}:${port_number}" >> ${ip_file}

            if [[ $h = $full_host_name ]]; then
               echo "Assigning own_port_number=$port_number for host $h"
               own_port_number=$port_number
            fi

            break
         fi
      fi

      port_number=$(($port_number+2))
      next_port_number=$(($next_port_number+2))
   done

   if [[ $port_number -ge $PORT_RANGE_END ]]; then
      echo "ERROR: Could not find a free port on host $h" 1>&2
      exit 1
   fi
done < ${host_file}
echo "--------------------------"
echo 


if [[ $own_port_number = "" ]]; then
   echo "ERROR: Failed to assign an own port number to this host" 1>2&
   exit 2
fi

echo "Launching H2O host..."
pbsdsh -v -u $SOURCE_DIR/launchH2O.bash $H2O_JAR $((10#$num_threads)) &
pbsdsh_pid=$!

echo "Sleeping for 100"
sleep 100
echo "Starting python..."

# Run it!
python ../../medline/pubmed.py "NA" ${PBS_O_WORKDIR}/${PBS_JOBID}.csv -i xml -o csv --config-file config_${test_id}.cfg --large-file --use-h2o --use-temp-files --num-docs $num_docs --h2o-url http://localhost:${own_port_number} --log-file-name ${PBS_JOBID}.log
python_return_code=$?

# Clean up batch hosts and ip addresses for this batch job
rm ${host_file} ${ip_file} >& /dev/null

if [[ $python_return_code -ne 0 ]]; then
   echo "ERROR: pubmed.py returned with error code $return_code" 1>&2
   exit 3
fi

# Kill H2O servers
echo "Killing pbsdsh()..."
kill $pbsdsh_pid
echo "killed"

exit 0
