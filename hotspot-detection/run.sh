#!/bin/bash
./detect-hotspots.pl ../pulls data/save-file
./chart.pl data/save-file data/
