#!/usr/bin/ksh

##################################################################################
## Script: logrotate_manual.sh
## Descricao: Executa rotacao de log manual em maquinas que nao tem o logrotate
##
## Autor: lucaslellis [at] gmail [dot] com
##
## Utilizacao: logrotate_manual.sh <RETENCAO EM DIAS> <CAMINHO COMPLETO DO LOG>
## Exemplo:    logrotate_manual.sh 30 "/u01/app/oracle/diag/rdbms/bw1/bw1/trace/alert_bw1.log"
##
##################################################################################

#
# Parametros:
#   $1 - retencao em dias
#   $2 - caminho do log
logrotate_file() {
    DIR_PATH=$(dirname "$2")
    FILE_PATH=$(basename "$2" ".log")
    EXEC_DATE=$(date '+%Y%m%d')
    GZIP_FILE_PATH="${FILE_PATH}_${EXEC_DATE}".gz

    if [ ! -f "$2" ]; then
        >&2 echo "O caminho $2 nao existe."
        return 1
    elif [ ! -s "$2" ]; then
        >&2 echo "O arquivo $2 esta vazio."
        return 1
    fi

    cd "$DIR_PATH" || return 1

    if [ -f "$GZIP_FILE_PATH" ]; then
        >&2 echo "O arquivo $GZIP_FILE_PATH ja existe."
        return 1
    fi

    # Compactar o arquivo atual e truncar - nesse passo pode haver perda de dados
    echo "Compactando o arquivo ${FILE_PATH}.log"
    gzip -c "${FILE_PATH}.log" > "${FILE_PATH}_${EXEC_DATE}".gz
    : > "${FILE_PATH}.log"

    # Mantem as ultimas <RETENCAO EM DIAS> copias
    cnt=0
    find "$DIR_PATH" -name "$FILE_PATH*.gz" | sort -d -r | while read -r fname; do
        cnt=$((cnt+1))
        if [ "$cnt" -gt "$1" ]; then
            echo "$fname"
            rm "$fname"
        fi
    done
}

# Checagem de parametros
if [ "$#" -lt  "2" ]; then
    echo "Numero Invalido de parametros."
    >&2 echo "Utilizaca correta: logrotate_manual.sh <RETENCAO EM DIAS> <CAMINHO COMPLETO DO LOG>"
    exit 1
fi

RETENCAO=$1
shift
params=""
set -A params -- "$@"
for fname in $params; do
    echo "Chamando a funcao para o arquivo $fname"
    logrotate_file "$RETENCAO" "$fname"
done
