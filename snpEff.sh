#!/bin/bash

export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

VCF_FILE="/Users/shreyanakum/Downloads/Manta-Output-Processing/MantaTestOutput/output/results/variants/candidateSmallIndels.vcf"
OUTPUT_FILE="smallIndels_annotated.vcf"
NCBI_FASTA_DIR="/Users/shreyanakum/Downloads/Manta-Output-Processing/ncbi_dataset"
NCBI_GTF_DIR="/Users/shreyanakum/Downloads/Manta-Output-Processing/ncbi_dataset_1"
GENOME_NAME="drosophila_r6"
SNPEFF_DIR="snpEff"

# files for chromosome renaming
RENAMED_VCF="candidateSmallIndels_renamed.vcf"
CHROMOSOME_MAP="ncbi_chromosome_mapping.txt"
ASSEMBLY_REPORT="GCF_000001215.4_assembly_report.txt"

CUSTOM_FASTA="$NCBI_FASTA_DIR/ncbi_dataset/data/GCF_000001215.4/GCF_000001215.4_Release_6_plus_ISO1_MT_genomic.fna"
CUSTOM_GTF="$NCBI_GTF_DIR/ncbi_dataset/data/GCF_000001215.4/genomic.gtf"

echo

if [ ! -f "$VCF_FILE" ]; then
    echo "Error: $VCF_FILE not found"
    exit 1
fi

if [ ! -f "$CUSTOM_FASTA" ]; then
    echo "Error: NCBI FASTA file $CUSTOM_FASTA not found"
    exit 1
fi

if [ ! -f "$CUSTOM_GTF" ]; then
    echo "Error: NCBI GTF file $CUSTOM_GTF not found"
    exit 1
fi

# echo "download NCBI assembly report for exact mappings"
# if [ ! -f "$ASSEMBLY_REPORT" ]; then
#     curl -s "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/215/GCF_000001215.4_Release_6_plus_ISO1_MT/GCF_000001215.4_Release_6_plus_ISO1_MT_assembly_report.txt" > "$ASSEMBLY_REPORT"
    
#     if [ $? -eq 0 ] && [ -s "$ASSEMBLY_REPORT" ]; then
#         echo "Assembly report downloaded successfully."
#     else
#         echo "Warning: Could not download assembly report. Using manual mapping."
#     fi
# else
#     echo "Assembly report already exists: $ASSEMBLY_REPORT"
# fi

echo

# make chromosome mapping
cat > "$CHROMOSOME_MAP" << 'EOF'
# Drosophila melanogaster GCF_000001215.4 chromosome mapping
# GenBank -> RefSeq mapping from NCBI assembly report
# These are the standard Drosophila chromosome mappings

# Major chromosome arms
AE014296.5	NC_004354.4	# Chromosome X
AE013599.5	NC_004352.2	# Chromosome 2L
AE014134.6	NC_004351.1	# Chromosome 2R  
AE014297.3	NC_004353.4	# Chromosome 3L
AE014135.4	NC_004348.3	# Chromosome 3R
AE014298.5	NC_012200.1	# Chromosome 4

# Mitochondrial genome
AE017196.1	NC_001709.1	# Mitochondrial genome

# Additional chromosomes/scaffolds - these might need verification
CP007074.1	NW_001845557.1
CP007075.1	NW_001845558.1
CP007077.1	NW_001845559.1
CP007078.1	NW_001845560.1

# If the above don't work, try keeping them as-is
# CP007074.1	CP007074.1
# CP007075.1	CP007075.1
# CP007077.1	CP007077.1
# CP007078.1	CP007078.1
EOF

echo "Chromosome mapping file created: $CHROMOSOME_MAP"

# current VCF chromosome distribution
echo
# curr chromosome distribution in VCF"
grep -v "^#" "$VCF_FILE" | cut -f1 | sort | uniq -c | sort -nr | head -10

echo
# renaming chromosomes in VCF file
bcftools annotate --rename-chrs "$CHROMOSOME_MAP" "$VCF_FILE" -o "$RENAMED_VCF"

if [ $? -ne 0 ]; then
    echo "Error: Failed to rename chromosomes in VCF file!"
    echo "Trying with simpler mapping"
    
    # make simpler mapping for problematic chromosomes
    cat > "${CHROMOSOME_MAP}_simple" << 'EOF'
AE014296.5	NC_004354.4
AE013599.5	NC_004352.2
AE014134.6	NC_004351.1
AE014297.3	NC_004353.4
AE014135.4	NC_004348.3
AE014298.5	NC_012200.1
EOF
    
    bcftools annotate --rename-chrs "${CHROMOSOME_MAP}_simple" "$VCF_FILE" -o "$RENAMED_VCF"
    
    if [ $? -ne 0 ]; then
        echo "Error: Chromosome renaming failed completely!"
        exit 1
    fi
fi

echo "Chromosomes renamed successfully!"

# renamed
echo
# chromosome distribution after renaming:"
grep -v "^#" "$RENAMED_VCF" | cut -f1 | sort | uniq -c | sort -nr | head -10

echo
# setting up snpEff database"

# custom genome database directory structure
mkdir -p $SNPEFF_DIR/data/$GENOME_NAME
mkdir -p $SNPEFF_DIR/data/genomes

# copy FASTA file to snpEff genomes directory
echo "Copying FASTA file to snpEff directory"
cp "$CUSTOM_FASTA" "$SNPEFF_DIR/data/genomes/$GENOME_NAME.fa"

# copy GTF file to snpEff data directory  
echo "Copying GTF file to snpEff directory"
cp "$CUSTOM_GTF" "$SNPEFF_DIR/data/$GENOME_NAME/genes.gtf"

# make snpEff config entry
CONFIG_FILE="$SNPEFF_DIR/snpEff.config"

if ! grep -q "$GENOME_NAME.genome" "$CONFIG_FILE"; then
    echo "Adding genome configuration to snpEff.config"
    echo "" >> "$CONFIG_FILE"
    echo "# Custom Drosophila melanogaster genome (NCBI Release 6)" >> "$CONFIG_FILE"
    echo "$GENOME_NAME.genome : Drosophila melanogaster Release 6" >> "$CONFIG_FILE"
else
    echo "Genome configuration already exists in snpEff.config"
fi

echo
# bilding snpEff database
java -jar $SNPEFF_DIR/snpEff.jar build -gtf22 -v $GENOME_NAME

if [ $? -ne 0 ]; then
    echo "Warning: Database build had issues. Trying with relaxed validation"
    java -jar $SNPEFF_DIR/snpEff.jar build -gtf22 -noCheckCds -noCheckProtein -v $GENOME_NAME
    
    if [ $? -ne 0 ]; then
        echo "Error: Database build failed!"
        exit 1
    fi
fi

echo

# running snpEff annotation
java -jar $SNPEFF_DIR/snpEff.jar ann -v $GENOME_NAME "$RENAMED_VCF" > "$OUTPUT_FILE"

TOTAL_VARIANTS=$(grep -v "^#" "$OUTPUT_FILE" | wc -l)
ERROR_COUNT=$(grep -v "^#" "$OUTPUT_FILE" | grep -c "ERROR_CHROMOSOME_NOT_FOUND" || echo "0")
ANNOTATED_COUNT=$((TOTAL_VARIANTS - ERROR_COUNT))
    
echo "---- FINAL STATISTICS ----"
echo "Total variants: $TOTAL_VARIANTS"
echo "Successfully annotated: $ANNOTATED_COUNT"
echo "Chromosome errors: $ERROR_COUNT"
echo "Success rate: $(( (ANNOTATED_COUNT * 100) / TOTAL_VARIANTS ))%"

echo
echo "Chromosomes still have naming issues ($ERROR_COUNT variants)"
echo "You may need to refine the chromosome mapping for complete coverage."

# which chromosomes still have errors
echo
echo "Chromosomes with errors:"
grep "ERROR_CHROMOSOME_NOT_FOUND" "$OUTPUT_FILE" | cut -f1 | sort | uniq -c | sort -nr

echo
echo "---- ANALYSIS COMPLETE ----"
echo "- og VCF: $VCF_FILE"
echo "- new VCF: $RENAMED_VCF"  
echo "- ann VCF: $OUTPUT_FILE"
echo "- mapping: $CHROMOSOME_MAP"
echo "- report: $ASSEMBLY_REPORT"