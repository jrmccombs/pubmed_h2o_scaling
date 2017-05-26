#!/bin/bash

################################################################################
# File: printResults.bash
#
# Description: This bash shell script reads the log files generated by each
# performance trial for each combination of number of nodes, number of
# threads, and number of clusters performance tested and prints the average run
# times for each node-thread configuration.  The average dissemination, average
# modeling, and average total time (dissemination plus modeling time) are
# printed.  The dissemination time is the time it takes to construct the H2O
# distributed data structure before calling the H2O distributed clustering
# routine.  The modeling time is the time taken to solve the clustering problem
# once the distributed data structure has been built, and the total time is the
# sum of the dissemination and modeling times.  If a log file exists, but does
# not contain any timing information, then a warning is printed.  If the number
# of trials is not as expected, then that is an indication that a trial failed
# to execute.
#
# Author: James R. McCombs, Pervasive Technology Institute, Indiana University 
################################################################################

unalias ls >& /dev/null

dirs=`ls -d -1 --color=never *_*_*`

echo "-----------------------------------------------------------------------------------------------"
echo " Num Nodes | Num Threads | Num Clusters | Num Trials | Avg. Dissem. | Avg. Model   | Avg. Total"
echo "           |             |              |            | Time         | Time         | Time" 
echo "-----------------------------------------------------------------------------------------------"

for i in $dirs; do
   num_nodes=${i%%_*}
   i2=${i#*_}
   num_threads=${i2%_*}
   num_clusters=${i##*_}

   cd $i/logs >& /dev/null

   if [[ $? -ne 0 ]]; then
      echo "WARNING: Log directory not found: $i/logs" 1>&2
      continue
   fi

   logs=`ls -1 ./*.log 2> /dev/null`

   if [[ $? -ne 0 ]]; then
      echo "WARNING: Log directory empty: $i/logs" 1>&2
      cd ../../
      continue
   fi

   dissem_values=""
   modeling_values=""
   total_values=""
   num_trials=0
   
   for log in $logs; do
      dissemination_line=`grep "dissemination time" $log`

      if [[ $? -ne 0 ]]; then
         echo "WARNING: no dissemination times found in $log" 1>&2
         continue
      fi

      modeling_line=`grep "modeling time" $log`

      if [[ $? -ne 0 ]]; then
         echo "WARNING: no modeling times found in $log" 1>&2
         continue
      fi

      total_line=`grep "total time" $log`

      if [[ $? -ne 0 ]]; then
         echo "WARNING: no total times found in $log" 1>&2
         continue
      fi

      dissem_value=${dissemination_line##*\ }
      modeling_value=${modeling_line##*\ }
      total_value=${total_line##*\ }

      if [[ $num_trials -eq 0 ]]; then
         dissem_values=$dissem_value
         modeling_values=$modeling_value
         total_values=$total_value
      else
         dissem_values="${dissem_values}+${dissem_value}"
         modeling_values="${modeling_values}+${modeling_value}"
         total_values="${total_values}+${total_value}"
      fi

      num_trials=$((num_trials+1))
   done

   if [[ $num_trials -ne 0 ]]; then
      avg_dissem_time=`echo "($dissem_values)/$num_trials" | bc -l`
      avg_modeling_time=`echo "($modeling_values)/$num_trials" | bc -l`
      avg_total_time=`echo "($total_values)/$num_trials" | bc -l`
      printf "%-9d   %-9d   %-9d      %-9d    %12.3f   %12.3f   %12.3f\n" $((10#$num_nodes)) $((10#$num_threads)) $((10#$num_clusters)) $((10#$num_trials)) $avg_dissem_time $avg_modeling_time $avg_total_time
   else
      printf "%-9d   %-9d   %-9d      %-9d    %12s     %12s     %12s\n" $((10#$num_nodes)) $((10#$num_threads)) $((10#num_clusters)) $((10#$num_trials)) "XXX" "XXX" "XXX"
   fi

   cd ../../
done
