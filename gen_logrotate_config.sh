#!/bin/bash
# Howie Jiang -- jiang@pythian.com -- June 14th 2017
#
# Find the alert.log and listener.log of the running instances and listeners
#

ASM_LOG_RETENTION=35
DB_LOG_RETENTION=35
LISTENER_LOG_RETENTION=35
DIR_BASE="$1"
SCRIPT_VERSAO_BANCO="${DIR_BASE}/../obter_versao_banco.sql"

#
# find the alert.log
#
OUT="${DIR_BASE}/oracle_asm_logrotate.conf"
rm -f $OUT
if [ -n "$(ps -ef | grep "asm_[p]mon" | grep -v grep)" ]; then
    (for I in $(\ps -ef | egrep "(asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//')
    do
            DB=$(echo ${I} | sed s/'[1-9]$//')

            . oraenv <<< ${I}       > /dev/null 2>&1

            sqlplus -S "/ as sysdba" << END_SQL
        set lines 200   ;
        set head off    ;
        set feed off    ;
        select replace(value,'cdump','trace') || '/*.log' from v\$parameter where name in ('core_dump_dest') ;
END_SQL

    done) | grep -v "^$" | awk -F, '{ printf $1 " "}' >> $OUT
    printf "\n" >> ${OUT}
    # only works with root access
    # host_nm=$(hostname | cut -d'.' -f1)
    # if [ -e "$ORACLE_HOME/log/$host_nm/alert${host_nm}.log" ]; then
    #     printf "$ORACLE_HOME/log/$host_nm/alert${host_nm}.log\n" >> $OUT
    # fi
    # if [ -e "$ORACLE_BASE/diag/crs/${host_nm}/crs/trace/alert${host_nm}.log" ]; then
    #     printf "$ORACLE_BASE/diag/crs/${host_nm}/crs/trace/alert${host_nm}.log\n" >> $OUT
    # fi
    cat << !                        >> ${OUT}
{
        daily
        rotate $ASM_LOG_RETENTION
        compress
        copytruncate
        nodelaycompress
        create 0640 $(whoami) dba
        notifempty
        dateext
}
!
fi

OUT="${DIR_BASE}/oracle_rdbms_logrotate.conf"
rm -f $OUT
(for I in $(\ps -ef | grep -E "(ora)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//')
do
        DB=$(echo ${I})

        . oraenv <<< ${DB}      > /dev/null 2>&1
    export ORACLE_SID=${I}

    versao_banco=$(\sqlplus -S "/ as sysdba" @${SCRIPT_VERSAO_BANCO})
    if [[ "$versao_banco" -lt "11" ]]; then
        sqlplus -S "/ as sysdba" << END_SQL
        set lines 200   ;
        set head off    ;
        set feed off    ;
        select value || '/*.log ' from v\$parameter where name in ('background_dump_dest') ;
END_SQL
    else
        sqlplus -S "/ as sysdba" << END_SQL
        set lines 200   ;
        set head off    ;
        set feed off    ;
        select value || '/*.log ' from v\$diag_info where name = 'Diag Trace' ;
END_SQL
    fi
done) | grep -v "^$" | awk -F, '{ printf $1 " " }' >> $OUT
printf "\n" >> ${OUT}
cat << !                        >> ${OUT}
{
        daily
        rotate $DB_LOG_RETENTION
        compress
        copytruncate
        nodelaycompress
        create 0640 $(whoami) dba
        notifempty
        dateext
}
!
#
# find the listeners log
#

# We need to have the CRS env to check the listeners
. oraenv <<< $(\ps -ef | grep "asm_[p]mon" | grep -v grep | sed s'/^.*_//g') > /dev/null 2>&1
OUT="${DIR_BASE}/oracle_listener_logrotate.conf"
rm -f $OUT
for L in $(\ps -ef | grep tnslsnr | grep -v grep | sed -r s'/tnslsnr \b([A-Za-z0-9_-]+)\b -.*$/tnslsnr \1/g' | grep -v sed | awk '{print $NF}')
do
        #LSRN_LOG=`lsnrctl status ${L} | grep "Listener Log File" | awk '{print $NF}' | dirname | sed 's/alert.*$/trace\//'``echo ${L} | tr '[:upper:]' '[:lower:]'`".log"
        LSNR_LOG=$(lsnrctl status LISTENER | grep "Listener Log File" | awk '{print $NF}' | xargs dirname | sed 's/alert/trace/')
        echo "$LSNR_LOG/*.log"    >>  ${OUT}
done
        cat << !                        >> ${OUT}
{
        daily
        rotate $LISTENER_LOG_RETENTION
        compress
        copytruncate
        nodelaycompress
        create 0640 $(whoami) dba
        notifempty
        dateext
}
!

#***********************************************************************************************#
#                               E N D      O F      S O U R C E                                 #
#***********************************************************************************************#

