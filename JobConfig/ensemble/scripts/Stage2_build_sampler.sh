#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g. Stage2_build_sampler.sh --tag MDS3c
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
OWNER="mu2e"
RELEASE=MDC2025
CURRENT="af"
TAG=""
VERBOSE=1

DIOVERSION=af
RMCVERSION=af
RPCVERSION=af
IPAVERSION=af

SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${RELEASE}${CURRENT}/setup.sh

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 Stage 2: Submit Ensemble Jobs"
echo "   Release: ${RELEASE}${CURRENT} | Owner: ${OWNER}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Default values
NJOBS=""
LIVETIME=""
RUN=1430
DIO_EMIN=95
RPC_EMIN=""
RMC_EMIN=""
kmax=""
IPA_EMIN=""
TMIN=""
BB=""
SAMPLINGSEED=1
COSMICTAG="MDC2025ac"
GEN="CRY"

# Loop: Get the next option
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        tag)
          TAG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        verbose)
          VERBOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        setup)
          SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dioversion)
          DIOVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rmcversion)
          RMCVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rpcversion)
          RPCVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        ipaversion)
          IPAVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        *)
          echo "Unknown option " ${OPTARG}
          exit_abnormal
          ;;
        esac;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;
    esac
done

# Extract config file from disk - MUCH SIMPLER WITH SOURCING
CONFIG=${TAG}.txt

if [[ ! -f ${CONFIG} ]]; then
  echo "❌ Error: Configuration file ${CONFIG} not found"
  exit 1
fi

echo "🔍 [1/6] Loading configuration from ${CONFIG}..."
source ${CONFIG}

# Map sourced variables to script variables
if [[ ! -z ${DEM_emin} ]]; then
  DIO_EMIN=${DEM_emin}
fi
if [[ ! -z ${RPC_TMIN} ]]; then
  TMIN=${RPC_TMIN}
fi
if [[ ! -z ${RPC_emin} ]]; then
  RPC_EMIN=${RPC_emin}
fi
if [[ ! -z ${RMC_emin} ]]; then
  RMC_EMIN=${RMC_emin}
fi
if [[ ! -z ${RMC_kmax} ]]; then
  kmax=${RMC_kmax}
fi
if [[ ! -z ${IPA_emin} ]]; then
  IPA_EMIN=${IPA_emin}
fi

echo "   ✓ Loaded configuration"
echo "   Parameters:"
echo "     • njobs: ${njobs}"
echo "     • livetime: ${onspilltime}"
echo "     • BB: ${BB}"
echo "     • CosmicGen: ${CosmicGen}"
echo "     • CosmicJob: ${CosmicJob}"
echo "     • DIO_EMIN: ${DEM_emin}"
echo "     • RPC_EMIN: ${RPC_emin}"
echo "     • RMC_EMIN: ${RMC_emin}"
echo "     • IPA_EMIN: ${IPA_emin}"
echo ""
echo "   Event Yields from Config:"
echo "     • DIO: ${dio_events:-N/A}"
echo "     • RPC Internal: ${rpc_internal_events:-N/A}"
echo "     • RPC External: ${rpc_external_events:-N/A}"
echo "     • RMC Internal: ${rmc_internal_events:-N/A}"
echo "     • RMC External: ${rmc_external_events:-N/A}"
echo "     • IPA Michel: ${ipa_events:-N/A}"
echo ""

# Use sourced variables directly
NJOBS=${njobs}
LIVETIME=${onspilltime}
COSMICTAG=${CosmicJob}
GEN=${CosmicGen}

rm -f filenames_CRYCosmic
rm -f filenames_DIO
rm -f filenames_RPCInternal
rm -f filenames_RPCExternal
rm -f filenames_RMCInternal
rm -f filenames_RMCExternal
rm -f filenames_IPAMichel
rm -f *.tar

echo "🔍 [2/6] Validating dataset availability (files and generated events)..."
echo "   Checking for ${NJOBS} files + sufficient generated events per dataset..."
VALIDATION_FAILED=0

# Define datasets to check with their corresponding yield variables
declare -a DATASETS=(
  "dts.mu2e.DIOtail${DIO_EMIN}.${RELEASE}${DIOVERSION}.art:DIO:dio_events"
  "dts.mu2e.RMCInternal.${RELEASE}${RMCVERSION}.art:RMCInternal:rmc_internal_events"
  "dts.mu2e.RMCExternal.${RELEASE}${RMCVERSION}.art:RMCExternal:rmc_external_events"
  "dts.mu2e.RPCInternalPhysical.${RELEASE}${RPCVERSION}.art:RPCInternal:rpc_internal_events"
  "dts.mu2e.RPCExternalPhysical.${RELEASE}${RPCVERSION}.art:RPCExternal:rpc_external_events"
  "dts.mu2e.IPAMuminusMichel.${RELEASE}${IPAVERSION}.art:IPAMichel:ipa_events"
)

# Also check CRYCosmic for files only (no yield check needed)
echo "   Checking CRYCosmic files (${NJOBS} files needed)..."
cry_file_count=$(mu2eDatasetFileList "dts.mu2e.CosmicSignal.${COSMICTAG}.art" 2>/dev/null | wc -l)
cry_file_count=$((cry_file_count + 0))  # Ensure it's a number
if [[ $cry_file_count -lt $NJOBS ]]; then
  echo "   ❌ CRYCosmic: Only ${cry_file_count} files available (need ${NJOBS})"
  VALIDATION_FAILED=1
else
  cry_generated=$(samDatasetsSummary.sh "dts.mu2e.CosmicSignal.${COSMICTAG}.art" 2>/dev/null | awk '/Generated/ {printf "%.0f", $2}')
  cry_generated=$((cry_generated + 0))  # Ensure it's a number
  if [[ -z "$cry_generated" ]] || [[ "$cry_generated" == "0" ]]; then
    echo "   ❌ CRYCosmic: No generated events or unable to retrieve count"
    VALIDATION_FAILED=1
  else
    cry_events_per_file=$((cry_generated / cry_file_count))
    echo "   ✓ CRYCosmic: ${cry_file_count} files, ${cry_generated} generated events (~${cry_events_per_file} per file)"
  fi
fi

# Check each dataset for files and events
for dataset_pair in "${DATASETS[@]}"; do
  IFS=':' read -r dataset_name dataset_label yield_var <<< "$dataset_pair"
  
  # Check file count
  file_count=$(mu2eDatasetFileList "$dataset_name" 2>/dev/null | wc -l)
  file_count=$((file_count + 0))  # Ensure it's a number
  if [[ -z "$file_count" ]] || [[ $file_count -lt $NJOBS ]]; then
    echo "   ❌ ${dataset_label}: Only ${file_count} files available (need ${NJOBS})"
    VALIDATION_FAILED=1
    continue
  fi
  
  # Check generated event count
  generated_events=$(samDatasetsSummary.sh "$dataset_name" 2>/dev/null | awk '/Generated/ {printf "%.0f", $2}')
  generated_events=$((generated_events + 0))  # Ensure it's a number
  
  if [[ -z "$generated_events" ]] || [[ "$generated_events" == "0" ]]; then
    echo "   ❌ ${dataset_label}: No generated events or unable to retrieve count"
    VALIDATION_FAILED=1
    continue
  fi
  
  # Get the expected yield from config and convert to integer
  expected_yield_raw="${!yield_var}"
  expected_yield_var=$(printf "%.0f" "$expected_yield_raw" 2>/dev/null)
  
  if [[ -z "$expected_yield_var" ]] || [[ "$expected_yield_var" == "0" ]]; then
    echo "   ⚠️  ${dataset_label}: No expected yield in config, skipping yield check"
    events_per_file=$((generated_events / file_count))
    echo "      Generated: ${generated_events} events (~${events_per_file} per file)"
  else
    if (( generated_events < expected_yield_var )); then
      echo "   ❌ ${dataset_label}: Insufficient generated events!"
      echo "      Generated: ${generated_events} events"
      echo "      Expected/Required: ${expected_yield_var} events"
      echo "      Shortfall: $((expected_yield_var - generated_events)) events"
      VALIDATION_FAILED=1
    else
      events_per_file=$((generated_events / file_count))
      echo "   ✓ ${dataset_label}: ${file_count} files, ${generated_events}/${expected_yield_var} generated events (~${events_per_file} per file)"
    fi
  fi
done

if [[ $VALIDATION_FAILED -eq 1 ]]; then
  echo ""
  echo "❌ ERROR: One or more datasets have insufficient files or generated events!"
  echo "   Please check dataset availability or adjust configuration"
  exit 1
fi

echo "   ✓ All datasets validated"
echo ""

echo "🔨 [3/6] Building file lists (${NJOBS} files per process)..."
mu2eDatasetFileList "dts.mu2e.CosmicSignal.${COSMICTAG}.art" | head -${NJOBS} > filenames_CRYCosmic
mu2eDatasetFileList "dts.mu2e.DIOtail${DIO_EMIN}.${RELEASE}${DIOVERSION}.art"| head -${NJOBS} > filenames_DIO
mu2eDatasetFileList "dts.mu2e.RMCInternal.${RELEASE}${RMCVERSION}.art" | head -${NJOBS} > filenames_RMCInternal
mu2eDatasetFileList "dts.mu2e.RMCExternal.${RELEASE}${RMCVERSION}.art" | head -${NJOBS} > filenames_RMCExternal
mu2eDatasetFileList "dts.mu2e.RPCInternalPhysical.${RELEASE}${RPCVERSION}.art" | head -${NJOBS} > filenames_RPCInternal
mu2eDatasetFileList "dts.mu2e.RPCExternalPhysical.${RELEASE}${RPCVERSION}.art" | head -${NJOBS} > filenames_RPCExternal
mu2eDatasetFileList "dts.mu2e.IPAMuminusMichel.${RELEASE}${IPAVERSION}.art" | head -${NJOBS} > filenames_IPAMichel
echo "   ✓ File lists created"
echo ""

echo "📝 [4/6] Generating template FCL files..."
make_template_fcl.py --BB=${BB} --release=${RELEASE}${CURRENT}  --tag=${TAG} --verbose=${VERBOSE} --livetime=${LIVETIME} --run=${RUN} --dioemin=${DIO_EMIN} --rpcemin=${RPC_EMIN} --rmcemin=${RMC_EMIN} --rmckmax=${RMC_kmax} --ipaemin=${IPA_EMIN} --tmin=${TMIN} --samplingseed=${SAMPLINGSEED} --prc "DIO" "CRYCosmic" "RPCInternal" "RPCExternal" "RMCInternal" "RMCExternal" "IPAMichel"
echo "   ✓ Template FCL files generated"
echo ""

echo "🏗️  [5/6] Building ensemble job configuration..."
echo "   Cleaning previous outputs..."
rm -f cnf.${OWNER}.ensemble${TAG}.${RELEASE}${CURRENT}.0.tar
rm -f filenames_CRYCosmic_${NJOBS}.txt
rm -f filenames_DIO_${NJOBS}.txt
rm -f filenames_RPCInternal_${NJOBS}.txt
rm -f filenames_RPCExternal_${NJOBS}.txt
rm -f filenames_RMCInternal_${NJOBS}.txt
rm -f filenames_RMCExternal_${NJOBS}.txt
rm -f filenames_IPAMichel_${NJOBS}.txt

echo "   Creating SAM file lists..."
samweb list-files "dh.dataset=dts.mu2e.CosmicSignal.${COSMICTAG}.art" | head -${NJOBS} > filenames_CRYCosmic_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.DIOtail${DIO_EMIN}.${RELEASE}${DIOVERSION}.art"  | head -${NJOBS} > filenames_DIO_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RMCInternal.${RELEASE}${RMCVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RMCInternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RMCExternal.${RELEASE}${RMCVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RMCExternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RPCInternalPhysical.${RELEASE}${RPCVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RPCInternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RPCExternalPhysical.${RELEASE}${RPCVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RPCExternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.IPAMuminusMichel.${RELEASE}${IPAVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_IPAMichel_${NJOBS}.txt
echo "   ✓ SAM file lists ready"
echo ""

echo "🚀 [6/6] Submitting ensemble jobs..."
DSCONF=${RELEASE}${CURRENT}
# note change setup to code to use a custom tarball
echo "   Running mu2ejobdef..."
cmd="mu2ejobdef --desc=ensemble${TAG} --dsconf=${DSCONF} --run=${RUN} --setup ${SETUP} --sampling=1:DIO:filenames_DIO_${NJOBS}.txt --sampling=1:CRYCosmic:filenames_CRYCosmic_${NJOBS}.txt --sampling=1:RPCInternal:filenames_RPCInternal_${NJOBS}.txt  --embed SamplingInput_sr0.fcl  --sampling=1:RPCExternal:filenames_RPCExternal_${NJOBS}.txt --sampling=1:RMCInternal:filenames_RMCInternal_${NJOBS}.txt --sampling=1:RMCExternal:filenames_RMCExternal_${NJOBS}.txt --sampling=1:IPAMichel:filenames_IPAMichel_${NJOBS}.txt --verb "

$cmd
parfile=$(ls cnf.*.tar)
# Remove cnf.
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}

idx=$(mu2ejobquery --njobs cnf.*.tar)
idx_format=$(printf "%07d" $idx)
echo "   ✓ Job definition created"
echo "   Total jobs: $idx"
echo ""

echo "   Creating index definition (size: $idx)..."
samweb create-definition idx_${index_dataset} "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < ${idx_format}"
echo "   ✓ Index definition created: idx_${index_dataset}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "✅ Stage 2 Complete!"
echo "   Tag: ${TAG}"
echo "   Release: ${RELEASE}${CURRENT}"
echo "   Total jobs: ${idx}"
echo "   Config file: cnf.${OWNER}.ensemble${TAG}.${RELEASE}${CURRENT}.0.tar"
echo "   Index definition: idx_${index_dataset}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
