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

# Checagem de parametros
if [ "$#" -ne  "2" ]; then
    echo 2>"Numero Invalido de parametros."
    echo 2>"Utilizaca correta: logrotate_manual.sh <CAMINHO COMPLETO DO LOG> <RETENCAO EM DIAS>"
    exit 1
elif [ ! -f "$1" ]; then
    echo 2>"O arquivo $1 nao existe."
    exit 1
fi

DIR_PATH=$(dirname "$1")
FILE_PATH=$(basename "$1")
EXEC_DATE=$(date '+%Y%m%d')

cd "$DIR_PATH" || exit 1

# Compactar o arquivo atual e truncar - nesse passo pode haver perda de dados
gzip -c "$FILE_PATH" > "${FILE_PATH}_${EXEC_DATE}".gz
: > "$FILE_PATH"
