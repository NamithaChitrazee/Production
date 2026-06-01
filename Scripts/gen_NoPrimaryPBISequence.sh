#!/usr/bin/bash
# script to create the fcl needed to convert a PBI sequence in text format into art primaries
# you must have 'setup muse' in a valid directory to run this script
#
# $1 is the DocDB number from which the sequence is taken  (currently 33344)
# $2 is the PBI sequence type (either Normal or Pathological)
# $3 is the maximum number of events/job
# $4 is the description field for the filename
# $5 is the run number
# $6 is the sub run number, default is 0
#
# Example:
# source Production/Scripts/gen_NoPrimaryPBISequence.sh 33344 Normal 1000 MDC2020p 1202

infile=/cvmfs/mu2e.opensciencegrid.org/DataFiles/PBI/PBI_$2_$1.txt
if [ ! -f $infile ]; then
    echo "Input file $infile not found!"
    exit 1
fi
nlines=`wc -l < $infile`
let nfiles=$nlines/$3
outroot="dts.mu2e.PBI$2_$1.$4."
fclroot="cnf.mu2e.PBISequence_$2_$1.$4."
dirname="NoPrimaryPBISequence_$1_$2"
runnumber=$5
subrunnumber=$6
if [[ "${subrunnumber}" == "" ]]; then
    subrunnumber=0
fi
rm -rf $dirname
mkdir $dirname
cd $dirname

echo "spliiting file $infile into $nfiles files"
split --lines $3 --numeric-suffixes --additional-suffix .txt $infile $outroot
#
# Now generate the fcl scripts to turn these into art files with PBI objects
#
nevents=0
for pbifile in $outroot*.txt; do
  # Use the text file name to create the fcl, art, and log file names
  fclfile=`echo ${pbifile} | sed s/txt/fcl/ | sed s/dts/cnf/`
  artfile=`echo ${pbifile} | sed s/txt/art/`
  logfile=`echo ${pbifile} | sed s/txt/log/`

  # Create the fcl file
  echo '#include "Production/JobConfig/primary/NoPrimaryPBISequence.fcl"' >> $fclfile
  echo source.fileNames : [ \"${pbifile}\" ] >> $fclfile
<<<<<<< HEAD
  echo source.runNumber : 1430 >> $fclfile
=======
  echo source.runNumber : ${runnumber} >> $fclfile
  echo source.firstSubRunNumber : ${subrunnumber} >> $fclfile
  echo source.firstEventNumber : ${nevents} >> $fclfile
>>>>>>> 31a38ea385231925fb3c398646345325aa39e1b7
  echo outputs.PrimaryOutput.fileName : \"$artfile\" >> $fclfile

  # Now run the job
  echo creating art file $artfile
  mu2e -c $fclfile >& $logfile
  printJson.sh --no-parents $artfile > $artfile.json

  # Increment the event count for the next file starting point
  nevents_file=`wc -l < ${pbifile}`
  nevents=$((nevents + nevents_file))
done

echo "Finished creating `ls $outroot*.txt | wc -l` files with $nevents events"
cd ../
