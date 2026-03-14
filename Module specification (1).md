# Module specification

The table below shows the requried input channels and relevant outputs that you need to include to run the nf-core modules in the seminar group work pipeline. Note that you need to define channels for the STAR index and GTF to run the STAR aligner, and channels for the SALMON index and transcriptome to run SALMON.

| --------------- | -------------- | ------------------------ |
| Module          | Input channels | Output channels          |
| --------------- | -------------- | -------------------------|
| FASTQC          | Sample sheet   | FASTQC.out.zip: QC plots |
| TRIMGALORE      | Sample sheet   | TRIMGALORE.out.reads: Trimmed reads <br> TRIMGALORE.out.zip: QC plots <br> TRIMGALORE.out.log: Log file |
| STAR_ALIGN      | Trimmed reads <br> STAR index <br> GTF <br> Whether to ignore GTF (false) | STAR_ALIGN.out.log_final: Log file <br> STAR_ALIGN.out.bam: Alignment BAM files |
| SALMON_QUANT    | Trimmed reads <br> SALMON index <br> GTF <br> Transcriptome <br> Alignment mode (false) <br> Override library type (false) | SALMON_QUANT.out.results: Quantification results |
| DUPRADAR        | Alignment BAM files <br> GTF | DUPRADAR.out.multiqc: MultiQC files |
| QUALIMAP_RNASEQ | Alignment BAM files <br> GTF | QUALIMAP_RNASEQ.out.results: Output data |
