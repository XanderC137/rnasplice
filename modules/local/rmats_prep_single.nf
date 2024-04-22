process RMATS_PREP_SINGLE {
    label 'process_high'

    conda 'bioconda::r-pairadise=1.0.0 bioconda::rmats=4.1.2'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-8ea76ff0a6a4c7e5c818fd4281abf918f92eeeae:121e48ab4817ec619c157a346458efca1ccf3c0a-0' :
        'biocontainers/mulled-v2-8ea76ff0a6a4c7e5c818fd4281abf918f92eeeae:121e48ab4817ec619c157a346458efca1ccf3c0a-0' }"

    input:
    path gtf                                     // /path/to/genome.gtf
    tuple val(contrast), val(cond1), val(meta1), path(bam1), path(bam1_text)
    val rmats_read_len                           // val params.rmats_read_len
    val rmats_splice_diff_cutoff                 // val params.rmats_splice_diff_cutoff
    val rmats_novel_splice_site                  // val params.rmats_novel_splice_site
    val rmats_min_intron_len                     // val params.rmats_min_intron_len
    val rmats_max_exon_len                       // val params.rmats_max_exon_len

    output:
    tuple val(contrast), path("rmats_temp/*") , emit: rmats_temp
    path "rmats_prep.log"                     , emit: log
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    // Only need to take meta1 as samples have same strand and read type info
    // - see rnasplice.nf input check for rmats
    def meta = meta1[0]
    def args = task.ext.args ?: ''

    // Take single/paired end information from meta
    def read_type = meta.single_end ? 'single' : 'paired'

    // Default strandedness to fr-unstranded - also if user supplies "unstranded"
    def strandedness = 'fr-unstranded'

    // Change strandedness based on user samplesheet input
    if (meta.strandedness == 'forward') {
        strandedness  = 'fr-secondstrand'
    } else if (meta.strandedness == 'reverse') {
        strandedness  = 'fr-firststrand'
    }

    // Whether user wants to run with novel splice sites flag
    def novel_splice_sites = rmats_novel_splice_site ? '--novelSS' : ''

    // Additional args for when running with --novelSS flag
    // User defined else defauls to 50, 500
    def min_intron_len = ''
    def max_exon_len   = ''
    if (rmats_novel_splice_site) {
        min_intron_len = rmats_min_intron_len ? "--mil ${rmats_min_intron_len}" : '--mil 50'
        max_exon_len   = rmats_max_exon_len ? "--mel ${rmats_max_exon_len}" : '--mel 500'
    }

    """
    rmats.py \\
        --b1 $bam1 \\
        -t $read_type \\
        --libType $strandedness \\
        --nthread $task.cpus \\
        --gtf $gtf \\
        --allow-clipping \\
        --readLength $rmats_read_len \\
        --variable-read-length \\
        --cstat $rmats_splice_diff_cutoff \\
        --task prep \\
        $novel_splice_sites \\
        $min_intron_len \\
        $max_exon_len \\
        --tmp rmats_temp \\
        --od rmats_prep 1> rmats_prep.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rmats: \$(echo \$(rmats.py --version) | sed -e "s/v//g")
    END_VERSIONS
    """
    }
