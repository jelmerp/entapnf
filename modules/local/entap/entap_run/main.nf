process ENTAP_RUN {
    label 'process_high'

    container "systemsgenetics/entap:flask"

    input:
    path (fasta)
    path (dbs)
    path (entap_config)
    val (seq_type)
    path (entap_db)
    path (eggnog_db)
    path (data_eggnog)
    path (blast_results)
    path (interproscan_results)

    output:
    path ('outfiles/final_results/**'), emit: tsv
    path "outfiles/*txt", emit: logs
    path "finalconf*", emit: final_config
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def run_type = seq_type == 'pep' ? '--runP' : '--runN'
    def db_list = dbs.join(" -d \$PWD/")
    """
    # Update the config file so it can find the eggnong diamond file
    cp $entap_config finalconf.$entap_config
    CWD=`echo \$PWD | perl -p -e 's/\\\\//\\\\\\\\\\\\//g'`
    perl -pi -e "s/eggnog-dmnd=eggnog_proteins.dmnd/eggnog-dmnd=\$CWD\\\\/$data_eggnog/" finalconf.$entap_config
    perl -pi -e "s/eggnog-sql=eggnog.db/eggnog-sql=\$CWD\\\\/$eggnog_db/" finalconf.$entap_config

    # Link the blast files to the directory EnTAP expects so it doesn't
    # rerun those.
    mkdir -p \$PWD/outfiles/similarity_search/DIAMOND
    files=`ls blast*.out`
    for f in \$files; do
        ln -s \$PWD/\$f \$PWD/outfiles/similarity_search/DIAMOND/\$f
    done;

    # Link the InterProScan file to the diretory EnTAP expects
    mkdir -p \$PWD/outfiles/ontology/InterProScan
    ln -s \$PWD/$interproscan_results \$PWD/outfiles/ontology/InterProScan/interpro_results.tsv

    # Run EnTAP
    EnTAP $run_type \\
        -t $task.cpus \\
        --ini finalconf.$entap_config \\
        --input $fasta \\
        -d \$PWD/$db_list \\
        --out-dir \$PWD/outfiles

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        EnTAP: \$(EnTAP --version 2>&1 | tail -n 1 | sed 's/^EnTAP  version: //')
    END_VERSIONS
    """
}
