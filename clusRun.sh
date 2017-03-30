#!/bin/bash
USER=`whoami`
NAMES=`cat /home/$USER/bin/nodenames.txt` #names from names.txt file
echo "launching $1"
for NAME in $NAMES; do
  #the & here will fork off a run for each node and move to the next, the wait at the end waits until all is complete
  echo "Connected to: " $NAME
  ssh -t $NAME $1
done
wait
echo "completed $1"

