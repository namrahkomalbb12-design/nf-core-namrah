/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

include { FASTQC           } from '../modules/nf-core/fastqc/main'
include { TRIMGALORE       } from '../modules/nf-core/trimgalore/main'
include { STAR_ALIGN       } from '../modules/nf-core/star/align/main'
include { SALMON_QUANT     } from '../modules/nf-core/salmon/quant/main'
include { DUPRADAR         } from '../modules/nf-core/dupradar/main'
include { QUALIMAP_RNASEQ  } from '../modules/nf-core/qualimap/rnaseq/main'
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
    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // 0. Reference Channels
    ch_star_index    = Channel.fromPath(params.star_index).first()
    ch_gtf           = Channel.fromPath(params.gtf).first()
    ch_salmon_index  = Channel.fromPath(params.salmon_index).first()
    ch_transcriptome = Channel.fromPath(params.transcriptome).first()

    // 1. FASTQC
    FASTQC ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{ it[1] })

    // 2. TRIMGALORE
    TRIMGALORE ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.zip.collect{ it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect{ it[1] })

   
  // 3. STAR_ALIGN 
    // This matches the 4-input signature: reads, index, gtf, ignore_gtf
    STAR_ALIGN ( 
        TRIMGALORE.out.reads, 
        ch_star_index.map { [ [:], it ] }, 
        ch_gtf.map { [ [:], it ] }, 
        false
    )
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect{ it[1] })

    // 4. SALMON_QUANT
    // Spec says: Reads, Index, GTF, Transcriptome, AlignmentMode (false), libType (false)
   SALMON_QUANT ( 
    TRIMGALORE.out.reads, 
    ch_salmon_index.map { [ [:], it ] }, 
    ch_gtf.map { [ [:], it ] }, 
    ch_transcriptome.map { [ [:], it ] }, 
    false, 
    false 
)
    ch_multiqc_files = ch_multiqc_files.mix(SALMON_QUANT.out.results.collect{ it[1] })

    // 5. DUPRADAR (New - from spec)
   // 5. DUPRADAR
    // We pass the BAM (which already has meta from STAR) and wrap the GTF
    DUPRADAR ( 
        STAR_ALIGN.out.bam, 
        ch_gtf.map { [ [:], it ] } 
    )
    ch_multiqc_files = ch_multiqc_files.mix(DUPRADAR.out.multiqc.collect{ it[1] })

    // 6. QUALIMAP_RNASEQ (New - from spec)
    QUALIMAP_RNASEQ ( 
        STAR_ALIGN.out.bam, 
        ch_gtf.map { [ [:], it ] } 
    )
    ch_multiqc_files = ch_multiqc_files.mix(QUALIMAP_RNASEQ.out.results.collect{ it[1] })

   
    // 7. MULTIQC
    // This version only takes ONE input: a list containing [meta, files]
    MULTIQC ( 
        ch_multiqc_files.collect().map { files -> [ [id:'multiqc'], files ] }
    )

    // Note: I have removed the ch_versions mixing for now to prevent the 
    // "No such property: versions" error until the pipeline logic is stable.
    
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
