#!/bin/bash
set -euo pipefail

# Environment
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

SNPEFF_DIR="snpEff"
SNPEFF_JAR="$SNPEFF_DIR/snpEff.jar"
CONFIG_FILE="$SNPEFF_DIR/snpEff.config"

# I/O
OUTPUTNAME="output_P01toP99" # output2 # output_P01P02 # output
FILENAME="candidateSmallIndels" # candidateSV # DiploidSV # candidateSmallIndels
VCF_FILE="/Volumes/Crucial X9/Manta-Output-Processing/MantaTestOutput/${OUTPUTNAME}/results/variants/${FILENAME}.vcf"
OUTPUT_FILE="./OUTPUT_1_to_100_RESULTS/${OUTPUTNAME}_${FILENAME}_annotated.vcf"
HTML_REPORT="./OUTPUT_1_to_100_RESULTS/${OUTPUTNAME}_${FILENAME}_annotation_summary.html"


# CORRECT GenBank paths (GCA_ not GCF_)
CUSTOM_FASTA="/Volumes/Crucial X9/Manta-Output-Processing/ncbi_dataset/ncbi_dataset/data/GCA_000001215.4/GCA_000001215.4_Release_6_plus_ISO1_MT_genomic.fna"
CUSTOM_GTF="/Volumes/Crucial X9/Manta-Output-Processing/GCA_000001215.4_Release_6_plus_ISO1_MT_genomic.gtf"

GENOME_NAME="ncbi_drosophila"

# Sanity checks + FASTA verification

echo "Files check"
for f in "$VCF_FILE" "$SNPEFF_JAR" "$CONFIG_FILE"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: File not found: $f" >&2
        exit 1
    fi
done

echo "All files found"

echo "VCF chromosome distribution:"
grep -v '^#' "$VCF_FILE" | cut -f1 | sort | uniq -c | sort -nr | head -5

# SKIP BUILD (alr done)

echo "Database built"
DB_PATH="$SNPEFF_DIR/data/$GENOME_NAME/snpEffectPredictor.bin"
if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH. Run build first." >&2
    exit 1
fi
echo "Database verification:"
ls -lh "$DB_PATH"
echo "Database ready ($GENOME_NAME)"

# Annotate VCF

echo "Running SnpEff annotation on: $VCF_FILE"
java -Xmx8G -jar "$SNPEFF_JAR" ann \
     -v \
     -stats "$HTML_REPORT" \
     "$GENOME_NAME" \
     "$VCF_FILE" > "$OUTPUT_FILE"

echo "Annotation finished."
echo "Annotated VCF: $OUTPUT_FILE"
echo "HTML report: $HTML_REPORT"

# Post-run statistics

echo
echo "Computing variant statistics"

TOTAL_IN=$(grep -v '^#' "$VCF_FILE"    | wc -l | awk '{print $1}')
TOTAL_OUT=$(grep -v '^#' "$OUTPUT_FILE"| wc -l | awk '{print $1}')
ERROR_COUNT=$(grep -v '^#' "$OUTPUT_FILE" 2>/dev/null | grep -c "ERROR_CHROMOSOME_NOT_FOUND" || echo 0)

echo "Input variants : $TOTAL_IN"
echo "Output variants: $TOTAL_OUT"
echo "ERROR_CHROMOSOME_NOT_FOUND: $ERROR_COUNT"

if [ "$TOTAL_OUT" -gt 0 ]; then
    ANNOTATED=$((TOTAL_OUT - ERROR_COUNT))
    if [ "$TOTAL_OUT" -gt 0 ]; then
        PCT=$((ANNOTATED * 100 / TOTAL_OUT))
    else
        PCT=0
    fi
    echo "Approx annotated variants: $ANNOTATED"
    echo "Approx success rate: ${PCT}%"
    
    echo
    echo "First 3 annotated variants (check for ANN= field):"
    grep -v '^#' "$OUTPUT_FILE" | head -3 | cut -f1-9
else
    echo "WARNING: No variants in output VCF."
fi

echo
echo "Done. $HTML_REPORT"
