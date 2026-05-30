#!/bin/bash

# Usage: ./livetime_checker.sh [dts_file] [tag]
# Example: ./livetime_checker.sh cosmics_2025.txt MDS3a

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "⏱️  Livetime Checker: Computing Total Livetime"
echo "═══════════════════════════════════════════════════════════════"
echo ""

DTS="${1:-cosmics_2025.txt}" # Command line arg or default
TAG="${2:-MDS3a}" # Command line arg or default

echo "[1/3] Cleaning up previous outputs..."
rm *.livetime 2>/dev/null
echo "   ✓ Previous livetime files cleaned"
echo ""

echo "[2/3] Processing cosmic dataset for livetime values..."
echo "   Input file: ${DTS}"
echo "   Processing with FCL: Offline/Print/fcl/printCosmicLivetime.fcl"
mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${DTS} | grep 'Livetime:' | awk -F: '{print NR","$NF}' > ${TAG}.livetime
echo "   ✓ Livetime values extracted"
echo ""

echo "[3/3] Calculating total livetime..."
LIVETIME=$(awk -F',' '{sum += $2} END {print sum}' ${TAG}.livetime)
event_count=$(wc -l < ${TAG}.livetime)
echo "   ✓ Processed ${event_count} livetime entries"
echo ""

# Append total to the output file
echo "" >> ${TAG}.livetime
echo "Total: ${LIVETIME}" >> ${TAG}.livetime

echo "═══════════════════════════════════════════════════════════════"
echo "✅ Livetime Calculation Complete!"
echo "   Total Livetime: ${LIVETIME}"
echo "   Tag: ${TAG}"
echo "   Results saved to: ${TAG}.livetime"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo ${LIVETIME}
