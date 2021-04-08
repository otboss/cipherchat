#!/bin/bash
export DEBUGGING=false;
read -p 'Launch in debugging mode? [y/N] ' choice;
if [ "$choice" == "y" -o "$choice" == "Y" ];
then
    cd "./bin";
    export DEBUGGING=true;
    ./node server.js; 
else
    cd "./bin";
    ./node index.js;    
fi
