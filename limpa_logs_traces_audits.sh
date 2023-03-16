#!/usr/bin/ksh

##################################################################################
## Script: limpa_logs_traces_audits.sh
## Descricao: Limpa logs, traces, audits, incidentes e core dumps
##            de todos os ORACLE_HOMEs de um usuario.
##            Caso haja multiplos owners de ORACLE_HOMEs, e necessario
##            agendar a rotina na crontab de cada usuario.
##
## Autor: lucaslellis [at] gmail [dot] com
##
## Pre-requisitos:
##      - Copiar os arquivos desta pasta para a pasta no servidor
##      - Conceder permissao de execucao
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/limpa_logs_traces_audits.sh
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/gen_logrotate_config.sh
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/logrotate_manual.sh
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/retencao.sh
##      - logrotate disponivel no PATH (desejavel)
##      - Incluir entrada na crontab, conforme arquivo entrada_crontab.txt
##      - Definir no script retencao.sh os prazos de retencao de cada tipo de arquivo
##################################################################################

if [ -f "${HOME}"/.bash_profile ]; then
    . "${HOME}"/.bash_profile
elif [ -f "${HOME}"/.profile ]; then
    . "${HOME}"/.profile
else
    >&2 echo "Arquivo de profile nao encontrado"
    exit 1
fi
export PATH=/usr/sbin:/sbin:$PATH

DIR_BASE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_LIMPEZA_AUDIT="${DIR_BASE}/obter_audit_dir.sql"
SCRIPT_LIMPEZA_TRACES_10="${DIR_BASE}/obter_traces_dir10g.sql"
SCRIPT_LIMPEZA_TRACES_11="${DIR_BASE}/obter_traces_dir11g.sql"
SCRIPT_VERSAO_BANCO="${DIR_BASE}/obter_versao_banco.sql"
DIR_LOCK_PREFIX="${DIR_BASE}/lockdir_"

LOGROTATE_STATE="${DIR_BASE}/logrotate/oracle_logrotate.status"

. "$DIR_BASE/retencao.sh"

DT_EXEC=$(date '+%Y%m%d')

# limpar arquivos .aud
limpar_audit() {
    cat <<ENDEND
##
## Limpando audits
##
ENDEND
    for inst in $(\ps -U $USER -f | grep -E "(ora|asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        export ORAENV_ASK=NO
        export ORACLE_SID="$inst"
        . oraenv > /dev/null 2>&1
        dir_audit=$(\sqlplus -S "/ as sysdba" @"${SCRIPT_LIMPEZA_AUDIT}")
        echo "Diretorio: ${dir_audit}"
        # o primeiro metodo e mais rapido, mas nao funciona em todos os ambientes
        # a saida de erros e ignorada por conta de erros de arquivo nao encontrado quando o arquivo nao existe
        find "${dir_audit}" -name '*.aud' -mtime +${DIAS_RETENCAO_AUDIT} -delete 2>/dev/null
        find "${dir_audit}" -name '*.aud' -mtime +${DIAS_RETENCAO_AUDIT} -exec rm {} + 2>/dev/null
        find "${dir_audit}" -name 'audit_*.zip' -mtime +${DIAS_RETENCAO_AUDIT} -delete 2>/dev/null
        find "${dir_audit}" -name 'audit_*.zip' -mtime +${DIAS_RETENCAO_AUDIT} -exec rm {} + 2>/dev/null

        # Gera zip com arquivos *.aud ainda dentro da retencao e remove os arquivos depois que o zip e completado
        ( cd "${dir_audit}" || exit; find . -name "*.aud" -exec zip --grow --quiet --move "${dir_audit}"/audit_"${DT_EXEC}".zip {} + )
    done
}

# limpar arquivos .trc e .trm
limpar_traces() {
    cat <<ENDEND
##
## Limpando traces
##
ENDEND
    for inst in $(\ps -U $USER -f | grep -E "(ora|asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        export ORAENV_ASK=NO
        export ORACLE_SID="$inst"
        . oraenv > /dev/null 2>&1

        versao_banco=$(\sqlplus -S "/ as sysdba" @"${SCRIPT_VERSAO_BANCO}")
        if [[ "$versao_banco" -lt "11" ]]; then
            SCRIPT_LIMPEZA_TRACES="${SCRIPT_LIMPEZA_TRACES_10}"
        else
            SCRIPT_LIMPEZA_TRACES="${SCRIPT_LIMPEZA_TRACES_11}"
        fi

        \sqlplus -S "/ as sysdba" @"${SCRIPT_LIMPEZA_TRACES}" > "${SCRIPT_LIMPEZA_TRACES}.out"
        for dir in $(cat "${SCRIPT_LIMPEZA_TRACES}.out"); do
            echo "Diretorio: ${dir}"
            # o primeiro metodo e mais rapido, mas nao funciona em todos os ambientes
            # a saida de erros e ignorada por conta de erros de arquivo nao encontrado quando o arquivo nao existe
            find "${dir}" -name '*.trc' -mtime +${DIAS_RETENCAO_TRACES} -delete 2>/dev/null
            find "${dir}" -name '*.trm' -mtime +${DIAS_RETENCAO_TRACES} -delete 2>/dev/null
            find "${dir}" -name '*.trc' -mtime +${DIAS_RETENCAO_TRACES} -exec rm {} + 2>/dev/null
            find "${dir}" -name '*.trm' -mtime +${DIAS_RETENCAO_TRACES} -exec rm {} + 2>/dev/null
        done
        rm -f "${SCRIPT_LIMPEZA_TRACES}".out
    done
}

# limpar logs em .xml, incidentes e core dumps do adrci
limpar_logs_xml_adrci() {
    retencao_adrci_min=$(( DIAS_RETENCAO_ADRCI * 60 * 24 ))
    cat <<ENDEND
##
## Limpando Logs em .xml, incidentes e core dumps do adrci
##
ENDEND
    for inst in $(\ps -U $USER -f | grep -E "(ora)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        export ORAENV_ASK=NO
        export ORACLE_SID="$inst"
        . oraenv > /dev/null 2>&1
        if [ -x "$(command -v adrci)" ]; then
            for adrci_home in $(\adrci exec="show homes" | tail -n +2 | grep -v user_root); do
                echo "adrci_home: ${adrci_home}"
                adrci exec="set home ${adrci_home}; migrate schema; purge -age ${retencao_adrci_min}"
            done
        else
            echo "adrci nao existe para o ORACLE_HOME ${ORACLE_HOME}"
        fi
    done
    for inst in $(\ps -U $USER -f | grep -E "(asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        export ORAENV_ASK=NO
        export ORACLE_SID="$inst"
        . oraenv > /dev/null 2>&1
        if [ -x "$(command -v adrci)" ]; then
            # Clusterware 11.2
            for adrci_home in $(\adrci exec="set base $ORACLE_HOME/log; show homes" | tail -n +2 | grep -v user_root); do
                echo "adrci_home: ${adrci_home}"
                adrci exec="set base $ORACLE_HOME/log; set home ${adrci_home}; migrate schema; purge -age ${retencao_adrci_min}"
            done
            for adrci_home in $(\adrci exec="show homes" | tail -n +2 | grep -v user_root); do
                echo "adrci_home: ${adrci_home}"
                adrci exec="set home ${adrci_home}; migrate schema; purge -age ${retencao_adrci_min}"
            done
        else
            echo "adrci nao existe para o ORACLE_HOME ${ORACLE_HOME}"
        fi
    done
}

# compactar e limpar alert logs e logs dos listeners
limpar_alerts_db_listener() {
    # gera os arquivos de configuracao do logrotate
    "${DIR_BASE}"/gen_logrotate_config.sh "${DIR_BASE}/logrotate"

    for arq_conf in "${DIR_BASE}"/logrotate/*.conf; do
        echo "logrotate: $arq_conf"
        if [ -x "$(command -v logrotate)" ]; then
            logrotate "$arq_conf" -s "$LOGROTATE_STATE" -v
        else
            echo "Chamando a funcao manual de logrotate"
            grep '.log' "$arq_conf" | while read -r line; do
                # A expansao do parametro $line e desejada
                "$DIR_BASE"/logrotate_manual.sh "$DIAS_RETENCAO_ADRCI" $line
            done
        fi
    done
}

# Funcao de entrada do script
main() {
    # Lista os diretorios de lock
    find "$DIR_BASE" -type d | grep "$DIR_LOCK_PREFIX" | while read -r lock_dir_name; do
        pid=${lock_dir_name#"$DIR_LOCK_PREFIX"}
        script_name=$(basename "$0")
        # verifica se o PID correspondente ao lock esta em execucao e se e do script de limpeza
        prog_exec=$(ps -U "$USER" -f | awk -v v_scriptname="$script_name" -v v_pid="$pid" '$0 ~ v_scriptname && $2 == v_pid && $0 !~ /awk/ { print v_pid }')

        if [[ -z "$prog_exec" ]]; then
            echo "Removendo o lock $lock_dir_name"
            rmdir "$lock_dir_name"
        else
            >&2 echo "Ja ha uma execucao em andamento."
            exit 1
        fi
    done

    echo "Criando o lock para a execucao atual."
    mkdir "${DIR_LOCK_PREFIX}$$"

    if [[ ! -d "$DIR_BASE/logrotate" ]]; then
        mkdir "$DIR_BASE/logrotate"
    fi

    limpar_audit
    limpar_traces
    limpar_logs_xml_adrci
    limpar_alerts_db_listener

    echo "Removendo o lock."
    rmdir "${DIR_LOCK_PREFIX}$$"
}

main
