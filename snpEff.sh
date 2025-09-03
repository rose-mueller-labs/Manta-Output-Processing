#!/bin/bash

# java env that acc works
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

VCF_FILE="/Users/shreyanakum/Downloads/Manta-Output-Processing/MantaTestOutput/output/results/variants/candidateSmallIndels.vcf"
OUTPUT_FILE="smallIndels_annotated.vcf"
GENOME="Drosophila_melanogaster"

echo "Starting snpEff annotation of Manta small indels..."

if [ ! -f "$VCF_FILE" ]; then
    echo "Error: $VCF_FILE not found!"
    exit 1
fi

# run annotation
java -jar snpEff/snpEff.jar ann $GENOME $VCF_FILE > $OUTPUT_FILE

# check if annotation completed successfully
if [ $? -eq 0 ]; then
    echo "Annotation completed successfully!"
    echo "Output file: $OUTPUT_FILE"
    echo "Summary HTML report: snpEff_summary.html"
    echo "Gene list: snpEff_genes.txt"
else
    echo "Error: snpEff annotation failed!"
    exit 1
fi

echo "Analysis complete!"