#!/bin/sh

PARSED_OPTIONS=$(getopt -n "$0"  -o bt:r: --long "batch,type:,id:"  -- "$@")
#Bad arguments, something has gone wrong with the getopt command.
if [ $? -ne 0 ];
then
    echo "Usage: $0 -t runType -r runId. To run in batch specify -b"
  exit 1
fi

eval set -- "$PARSED_OPTIONS"

batch=0
runType=""
runId=""

while true;
do
  case "$1" in
  
    -b|--batch)
#      echo "Running in batch"
      batch=1
      shift;;
 
    -t|--type)
      if [ -n "$2" ];
      then
	  runType=$2
      fi
      shift 2;;

    -r|--id)
      if [ -n "$2" ];
      then
	  runId=$2
      fi
      shift 2;;
 
    --)
      shift
      break;;
  esac
done

if [ "$runId" == "" ] || [ "$runType" == "" ];
then
    echo "Usage: $0 -t runType -r runId. To run in batch specify -b"
  exit 1
fi

source ./processData.ini

mkdir -p jobs/${runType}_${runId}

cat > jobs/${runType}_${runId}/job_${runType}_${runId}.sh <<EOF

source /cvmfs/sft.cern.ch/lcg/views/LCG_94/x86_64-slc6-gcc8-opt/setup.sh

#Convert data
echo " ---> Running conversion for ${runType} run ${runId} <---"

tmpDir=\`mktemp -d -p ${tmpFolder}\`
cd \${tmpDir}

mkdir -p log/
mkdir -p dataTree/
mkdir -p raw

scp -r cmsdaq@10.0.0.44:/data/cmsdaq/${runType}/raw/${runId} raw/ 2>&1
 
cd ${drs4daqFolder}

drs4analysis/drs4convert \${tmpDir}/raw/${runId} \${tmpDir}/dataTree/${runId} 

# stageout  back via ssh to pccmsdaq01 
#scp -r \${tmpDir}/dataTree/${runId}  cmsdaq@10.0.0.44:/data/cmsdaq/${runType}/dataTree/ 2>&1

# stageout to dCache
mkdir -p ${dCacheFolder}/${runType}
mkdir -p ${dCacheFolder}/${runType}/dataTree/
mkdir -p ${dCacheFolder}/${runType}/dataTree/${runId}
for file in \`find \${tmpDir}/dataTree/${runId}/ -type f\`; do cp -v \$file ${dCacheFolder}/${runType}/dataTree/${runId}/; done

# Run H4Analysis
echo " ---> Running analysis for ${runType} run ${runId} <---"

cd \${tmpDir}
mkdir -p ntuples

#Prepare cfg
cat ${h4AnalysisConfigFolder}/DRS4_${runType}_TEMPLATE.conf | sed -e "s%DATA_FOLDER/RUN_TYPE%\${tmpDir}%g" | sed -e "s%RUN_TYPE%${runType}%g"  | sed -e "s%RUN_ID%${runId}%g" > h4Analysis_${runType}_${runId}.conf

cd ${h4AnalysisFolder}
bin/H4Reco \${tmpDir}/h4Analysis_${runType}_${runId}.conf

#stageout output
scp \${tmpDir}/ntuples/h4Reco_${runId}.root  cmsdaq@10.0.0.44:/data/cmsdaq/${runType}/ntuples/ 2>&1

#stageout dCache
mkdir -p ${dCacheFolder}/${runType}
mkdir -p ${dCacheFolder}/${runType}/ntuples/
cp -v \${tmpDir}/ntuples/h4Reco_${runId}.root ${dCacheFolder}/${runType}/ntuples/

rm -rf \${tmpDir}
EOF

chmod +x jobs/${runType}_${runId}/job_${runType}_${runId}.sh

if [ ${batch} -eq 1 ]; then
    bsub -q cmsshort -o jobs/${runType}_${runId}/job_${runType}_${runId}.out -e jobs/${runType}_${runId}/job_${runType}_${runId}.err -J ${runType}_${runId} < jobs/${runType}_${runId}/job_${runType}_${runId}.sh
else
    echo "Running interactively job_${runType}_${runId}.sh"
    jobs/${runType}_${runId}/job_${runType}_${runId}.sh > jobs/${runType}_${runId}/job_${runType}_${runId}.out 2>&1
fi
