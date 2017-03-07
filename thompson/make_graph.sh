#!/bin/sh

if [ ! -f ./nfa ]
then
   gcc nfa.c -o ./nfa
fi
./nfa "$1" _ | perl make-graph.pl | tee graph.dot
dot -ograph.png -Tpng graph.dot
