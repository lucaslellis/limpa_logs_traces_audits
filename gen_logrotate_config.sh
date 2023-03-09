#!/usr/bin/ksh
# Howie Jiang -- jiang@pythian.com -- June 14th 2017
#
# Find the alert.log and listener.log of the running instances and listeners
#


DIR_BASE="$1"
SCRIPT_VERSAO_BANCO="${DIR_BASE}/../obter_versao_banco.sql"

. "$DIR_BASE/../retencao.sh"

#
# find the alert.log
#
OUT="${DIR_BASE}/oracle_asm_logrotate.conf"
rm -f $OUT
if [ -n "$(ps -U $USER -f | grep "asm_[p]mon" | grep -v grep)" ]; then
    (for I in $(\ps -U $USER -f | egrep "(asm)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//')
    do
            DB=$(echo ${I} | sed s/'[1-9]$//')
            export ORAENV_ASK=NO
            export ORACLE_SID="${I}"
            . oraenv > /dev/null 2>&1

            sqlplus -S "/ as sysdba" << END_SQL
        set lines 200   ;
        set head off    ;
        set feed off    ;
        select replace(value,'cdump','trace') || '/*.log' from v\$parameter where name in ('core_dump_dest') ;
END_SQL

    done) | grep -v "^$" | awk -F, '{ printf $1 " "}' >> $OUT
    if [ -s "$OUT" ]; then
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
fi

OUT="${DIR_BASE}/oracle_rdbms_logrotate.conf"
rm -f $OUT
(for I in $(\ps -U $USER -f | grep -E "(ora)_[p]mon_" | awk '{print $NF}' | sed 's/.*pmon_//')
do
        DB=$(echo ${I})
        export ORAENV_ASK=NO
        export ORACLE_SID="${DB}"
        . oraenv > /dev/null 2>&1
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
    if [ -s "$OUT" ]; then
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
    fi
#
# find the listeners log
#

# We need to have the CRS env to check the listeners
export ORAENV_ASK=NO
export ORACLE_SID=$(\ps -U $USER -f | grep "asm_[p]mon" | grep -v grep | sed s'/^.*_//g')
if [ ! -z "$ORACLE_SID" ]; then
    . oraenv > /dev/null 2>&1 0</dev/null
fi
OUT="${DIR_BASE}/oracle_listener_logrotate.conf"
rm -f $OUT

ps -U $USER -f | grep "[t]nslsnr" | while read -r line; do
    ORACLE_HOME=$(echo "$line" | awk '{for(i=1;i<=NF;i++)if($i ~ "tnslsnr"){print $(i);break}}' | sed 's;/bin/tnslsnr;;g')
    LSNR=$(echo "$line" | awk '{for(i=1;i<=NF;i++)if($i ~ "tnslsnr"){print $(i+1);break}}')
    export PATH=$ORACLE_HOME/bin:$PATH
    export LIBPATH=$ORACLE_HOME/lib:$LIBPATH
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
    export ORACLE_HOME

    LSNR_LOG=$(lsnrctl status "${LSNR}" | grep "Listener Log File" | awk '{print $NF}' | xargs dirname | sed 's/alert/trace/')
    echo "$LSNR_LOG/*.log" >>  ${OUT}
done
if [ -s "$OUT" ]; then
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
fi
#***********************************************************************************************#
#                               E N D      O F      S O U R C E                                 #
#***********************************************************************************************#

