#!/bin/bash

################################################################################
# File: launchH2O.bash
#
# Description: This bash shell script, intended to be called by pbsdsh or
# other utility for launching concurrent processes in a distributed environment,
# instantiates an H2O process for executing distributed machine learning
# tasks.  The h2o_jar argument must be a full path to an H2O java jar file and
# num_threads is the number of worker threads the H2O process is to apply to
# the machine learning workloads.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

prog="launchH2O.bash"
USAGE="USAGE: $prog h2o_jar num_threads"

if [[ $# -ne 2 ]]; then
   echo "$USAGE"
   exit 1
fi

H2O_JAR=$1
NUM_THREADS=$2

# pbsdsh introduces a syntax bug into the PATH variable, so override it
PATH=/usr/local/bin:/bin:/usr/bin

cd $PBS_O_WORKDIR

echo "PATH=$PATH"

fullHostName=`hostname`
hostName=${fullHostName%%.*}
nodeIpAddress=`nslookup $fullHostName | awk '/^Address: / { print $2 ; exit }'`
h2oLogFile=h2o_${hostName}_${PBS_JOBID}.log

# Get the port number from the IP file
nodeIpAddress=${nodeIpAddress}
entry=`cat ipfile_${PBS_JOBID} | grep ${nodeIpAddress}:`

# Check if grep was empty
if [[ $? -ne 0 ]]; then
   echo "ERROR($prog): Could not find local host IP $nodeIpAddress in ipfile" 1>&2
   exit 1
fi

port=${entry##*:}

echo "--------------------------------"
echo "PBS environment "
echo "--------------------------------"
echo "PBS_O_WORKDIR : " $PBS_O_WORKDIR
echo "PBS_O_HOST    : " $PBS_O_HOST
echo "--------------------------------"
echo "local environment  "
echo "--------------------------------"
echo "H2O_JAR       : " $H2O_JAR
echo "NUM_THREADS   : " $NUM_THREADS
echo "fullHostName  : " $fullHostName
echo "hostName      : " $hostName
echo "nodeIpAddress : " $nodeIpAddress
echo "port          : " $port
echo "h2oLogFile    : " $h2oLogFile
echo "--------------------------------"
echo "Running H2O..."

java -Xmx30g -jar ${H2O_JAR} -ip ${nodeIpAddress} -flatfile ipfile_${PBS_JOBID} -port ${port} -nthreads ${NUM_THREADS} >& ${h2oLogFile}
exit 0
