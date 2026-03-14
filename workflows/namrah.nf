/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
// ADDING THE MODULES I INTALLED
include { FASTQC           } from '../modules/nf-core/fastqc/main'
include { TRIMGALORE       } from '../modules/nf-core/trimgalore/main'
include { STAR_ALIGN       } from '../modules/nf-core/star/align/main'
include { SALMON_QUANT     } from '../modules/nf-core/salmon/quant/main'
include { MULTIQC          } from '../modules/nf-core/multiqc/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NAMRAH {

   take:
    ch_samplesheet

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // References
    ch_star_index    = Channel.fromPath(params.star_index).first()
    ch_gtf           = Channel.fromPath(params.gtf).first()
    ch_salmon_index  = Channel.fromPath(params.salmon_index).first()
    ch_transcriptome = Channel.fromPath(params.transcriptome).first()

    // 1. FASTQC
    // 1. FASTQC
    FASTQC ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{ it[1] })
    ch_versions      = ch_versions.mix(FASTQC.out.versions_fastqc)

    // 2. TRIMGALORE
    TRIMGALORE ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect{ it[1] })
    ch_versions      = ch_versions.mix(TRIMGALORE.out.versions_trimgalore)

    // 3. STAR_ALIGN
    // Using TRIMGALORE.out.reads (meta + fastq)
    STAR_ALIGN ( TRIMGALORE.out.reads, ch_star_index, ch_gtf, false ) 
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect{ it[1] })
    ch_versions      = ch_versions.mix(STAR_ALIGN.out.versions_star)

    // 4. SALMON_QUANT
    // Pass the unsorted BAM from STAR
    SALMON_QUANT ( STAR_ALIGN.out.bam_unsorted, ch_salmon_index, ch_gtf, ch_transcriptome, true, 'IU' )
    ch_multiqc_files = ch_multiqc_files.mix(SALMON_QUANT.out.results.collect{ it[1] })
    ch_versions      = ch_versions.mix(SALMON_QUANT.out.versions_salmon)

    // 5. MULTIQC
    MULTIQC ( ch_multiqc_files.collect() ) 
    ch_versions = ch_versions.mix(MULTIQC.out.versions_multiqc)
    //
    // Collate and save software versions
    //
   //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions.unique().collect())
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:     'software_versions.yml',
            sort:     true,
            newLine:  true
        ).set { ch_collated_versions }

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
