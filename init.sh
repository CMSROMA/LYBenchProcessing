#!/bin/sh

git clone git@github.com:CMSROMA/DRS4_DAQ.git
cd DRS4_DAQ
git checkout -b convertOnly origin/convertOnly
cd ..

git clone --recursive git@github.com:CMSROMA/H4Analysis.git
cd H4Analysis
git checkout -b LYBench_CMSRMLab2 origin/LYBench_CMSRMLab2
cd ..

#source /cvmfs/sft.cern.ch/lcg/views/LCG_94/x86_64-centos7-gcc8-opt/setup.sh
source /cvmfs/sft.cern.ch/lcg/views/LCG_94/x86_64-slc6-gcc8-opt/setup.sh

echo "Compiling DRS4_DAQ"

cd DRS4_DAQ
cmake .
make 

echo "Compiling H4Analysis"
cd H4Analysis
make -j 4
cd ..

echo "Please remember to update your processData.ini configuration"
