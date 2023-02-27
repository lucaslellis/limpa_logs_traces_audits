#!/bin/bash

##################################################################################
## Script: logrotate_manual.sh
## Descricao: Executa rotacao de log manual em maquinas que nao tem o logrotate
##
## Autor: lucaslellis [at] gmail [dot] com
##
## Utilizacao: logrotate_manual.sh <CAMINHO COMPLETO DO LOG> <RETENCAO EM DIAS>
## Exemplo:    logrotate_manual.sh "/u01/app/oracle/diag/rdbms/bw1/bw1/trace/alert_bw1.log" 30
##
##################################################################################

#
# Parametros:
#   $1 - caminho do log
#   $2 - retencao em dias
logrotate_file() {
    DIR_PATH=$(dirname "$1")
    FILE_PATH=$(basename "$1" ".log")
    EXEC_DATE=$(date '+%Y%m%d')
    GZIP_FILE_PATH="${FILE_PATH}_${EXEC_DATE}".gz

    cd "$DIR_PATH" || exit 1

    if [ -f "$GZIP_FILE_PATH" ]; then
        >&2 echo "O arquivo $GZIP_FILE_PATH ja existe."
        exit 1
    fi

    # Compactar o arquivo atual e truncar - nesse passo pode haver perda de dados
    gzip -c "${FILE_PATH}.log" > "${FILE_PATH}_${EXEC_DATE}".gz
    : > "${FILE_PATH}.log"

    # Mantem as ultimas <RETENCAO EM DIAS> copias
    cnt=0
    find "$DIR_PATH" -name "$FILE_PATH*.gz" | sort -d -r | while read -r fname; do
        cnt=$((cnt+1))
        if [ "$cnt" -gt "$2" ]; then
            echo "$fname"
            rm "$fname"
        fi
    done
}

# Checagem de parametros
if [ "$#" -ne  "2" ]; then
    echo "Numero Invalido de parametros."
    >&2 echo "Utilizaca correta: logrotate_manual.sh <CAMINHO COMPLETO DO LOG> <RETENCAO EM DIAS>"
    exit 1
elif [ ! -f "$1" ]; then
    >&2 echo "O caminho $1 nao existe."
    exit 1
fi

logrotate_file "$1" "$2"
