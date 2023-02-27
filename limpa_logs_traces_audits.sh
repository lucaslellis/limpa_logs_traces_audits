#!/bin/bash

##################################################################################
## Script: limpa_logs_traces_audits.sh
## Descricao: Limpa logs, traces, audits, incidentes e core dumps
##            de todos os ORACLE_HOMEs de um servidor.
##
## Autor: lucaslellis [at] gmail [dot] com
##
## Pre-requisitos:
##      - Criar diretorios
##             mkdir -p /home/oracle/scripts/limpa_logs_traces_audits/logrotate
##      - Copiar os arquivos desta pasta para a pasta no servidor
##      - Conceder permissao de execucao
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/limpa_logs_traces_audits.sh
##             chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/gen_logrotate_config.sh
##      - logrotate disponivel no PATH
##      - Incluir entrada na crontab, conforme arquivo entrada_crontab.txt
##################################################################################

if [ -f "${HOME}"/.bash_profile ]; then
    source "${HOME}"/.bash_profile
elif [ -f "${HOME}"/.profile ]; then
    source "${HOME}"/.profile
else
    >&2 echo "Arquivo de profile nao encontrado"
    exit 1
fi
export PATH=/usr/sbin:/sbin:$PATH

DIR_BASE="${HOME}/scripts/limpa_logs_traces_audits"
SCRIPT_LIMPEZA_AUDIT="${DIR_BASE}/obter_audit_dir.sql"
SCRIPT_LIMPEZA_TRACES_10="${DIR_BASE}/obter_traces_dir10g.sql"
SCRIPT_LIMPEZA_TRACES_11="${DIR_BASE}/obter_traces_dir11g.sql"
SCRIPT_VERSAO_BANCO="${DIR_BASE}/obter_versao_banco.sql"
ARQ_PID="$DIR_BASE/limpa_logs_traces_audits.pid"

LOGROTATE_STATE="${DIR_BASE}/logrotate/oracle_logrotate.status"

DIAS_RETENCAO_AUDIT=366
DIAS_RETENCAO_TRACES=35
DIAS_RETENCAO_ADRCI=35

DT_EXEC=$(date '+%Y%m%d')

# limpar arquivos .aud
limpar_audit() {
    cat <<ENDEND
##
## Limpando audits
##
ENDEND
    for inst in $(\ps -ef | grep -E "(ora|asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        . oraenv <<< "$inst" > /dev/null 2>&1
        dir_audit=$(\sqlplus -S "/ as sysdba" @"${SCRIPT_LIMPEZA_AUDIT}")
        echo "Diretorio: ${dir_audit}"
        # o primeiro metodo e mais rapido, mas nao funciona em todos os ambientes
        find "${dir_audit}" -name '*.aud' -mtime +${DIAS_RETENCAO_AUDIT} -delete 2>/dev/null
        find "${dir_audit}" -name '*.aud' -mtime +${DIAS_RETENCAO_AUDIT} -print0 | xargs -0 -I{} rm {}
        find "${dir_audit}" -name 'audit_*.zip' -mtime +${DIAS_RETENCAO_AUDIT} -delete 2>/dev/null
        find "${dir_audit}" -name 'audit_*.zip' -mtime +${DIAS_RETENCAO_AUDIT} -print0 | xargs -0 -I{} rm {}

        # Gera zip com arquivos *.aud ainda dentro da retencao e remove os arquivos depois que o zip e completado
        # ( cd "${dir_audit}" || exit; find . -name "*.aud" | zip --grow --quiet --move "${dir_audit}"/audit_"${DT_EXEC}".zip -@ )
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
    for inst in $(\ps -ef | grep -E "(ora|asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        . oraenv <<< "$inst" > /dev/null 2>&1

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
            find "${dir}" -name '*.trc' -mtime +${DIAS_RETENCAO_TRACES} -delete
            find "${dir}" -name '*.trm' -mtime +${DIAS_RETENCAO_TRACES} -delete
            find "${dir}" -name '*.trc' -mtime +${DIAS_RETENCAO_TRACES} -print0 | xargs -0 -I{} rm {}
            find "${dir}" -name '*.trm' -mtime +${DIAS_RETENCAO_TRACES} -print0 | xargs -0 -I{} rm {}
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
    for inst in $(\ps -ef | grep -E "(ora)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        . oraenv <<< "$inst" > /dev/null 2>&1
        if [ -x "$(command -v adrci)" ]; then
            for adrci_home in $(\adrci exec="show homes" | tail --lines=+2); do
                echo "adrci_home: ${adrci_home}"
                adrci exec="set home ${adrci_home}; migrate schema; purge -age ${retencao_adrci_min}"
            done
        else
            echo "adrci nao existe para o ORACLE_HOME ${ORACLE_HOME}"
        fi
    done
    for inst in $(\ps -ef | grep -E "(asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//'); do
        echo "Instancia: ${inst}"
        . oraenv <<< "$inst" > /dev/null 2>&1
        if [ -x "$(command -v adrci)" ]; then
            for adrci_home in $(\adrci exec="set base $ORACLE_HOME/log; show homes" | tail --lines=+2); do
                echo "adrci_home: ${adrci_home}"
                adrci exec="set base $ORACLE_HOME/log; set home ${adrci_home}; migrate schema; purge -age ${retencao_adrci_min}"
            done
            for adrci_home in $(\adrci exec="show homes" | tail --lines=+2); do
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
        logrotate "$arq_conf" -s "$LOGROTATE_STATE" -v
    done
}

# Funcao de entrada do script
main() {
    echo $$ >> "$ARQ_PID"

    limpar_audit
    limpar_traces
    limpar_logs_xml_adrci
    limpar_alerts_db_listener

    rm "$ARQ_PID"
}

main
