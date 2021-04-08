#!/bin/bash
cd "./bin";
printf "\n\n";
printf "===============\n";
printf "STOPPING SERVER\n";
printf "===============\n";
printf "Press Ctrl+C to cancel..\n\n"
sleep 2;
./npx forever stopall;
killall node;
