# Manta Output Processing

Processes Illumina Manta structural variant VCF files for Drosophila melanogaster (Release 6 + ISO1 MT) using SnpEff annotation.

## Inputs
```
MantaTestOutput/output/results/variants/candidateSmallIndels.vcf
GCA_000001215.4_Release_6_plus_ISO1_MT_genomic.fna  (GenBank FASTA)
GCA_000001215.4_Release_6_plus_ISO1_MT_genomic.gtf  (matching GTF)
snpEff/ (pre-built ncbi_drosophila database)
```

## Outputs
```
OUTPUTS/output_candidateSmallIndels_annotated.vcf
OUTPUT_HTMLS/output_candidateSmallIndels_annotation_summary.html
```

## Usage
```bash
OUTPUTNAME="output"
FILENAME="candidateSmallIndels"
./snpEff.sh
```