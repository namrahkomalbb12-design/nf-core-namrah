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
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = channel.empty()
    // 1. Initialize a channel for MultiQC report files
    ch_multiqc_files = Channel.empty()

    // 2. MODULE: FastQC
    // Note: ch_samplesheet is passed from the entry main.nf
    FASTQC ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions)

    // 3. MODULE: TrimGalore
    TRIMGALORE ( ch_samplesheet )
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect{it[1]})
    ch_versions = ch_versions.mix(TRIMGALORE.out.versions)

    // 4. MODULE: STAR Alignment
    // Uses trimmed reads and the parameters you set in test.config
    STAR_ALIGN ( 
        TRIMGALORE.out.reads, 
        params.star_index, 
        params.gtf, 
        true, 
        '', 
        '' 
    )
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log.collect{it[1]})
    ch_versions = ch_versions.mix(STAR_ALIGN.out.versions)

    // 5. MODULE: Salmon Quantification
    SALMON_QUANT ( 
        STAR_ALIGN.out.bam, 
        params.salmon_index, 
        params.gtf, 
        params.transcriptome, 
        true, 
        'IU' 
    )
    ch_multiqc_files = ch_multiqc_files.mix(SALMON_QUANT.out.results.collect{it[1]})
    ch_versions = ch_versions.mix(SALMON_QUANT.out.versions)

    // 6. MODULE: MultiQC
    // This aggregates all reports into the final HTML
    MULTIQC ( ch_multiqc_files.collect() )
    ch_versions = ch_versions.mix(MULTIQC.out.versions)

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'namrah_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
