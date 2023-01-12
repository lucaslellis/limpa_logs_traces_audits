set newpage none pagesize 0 feed off head off trimspool on lines 2000 echo off
col value for a2000

select substr(version, 1, instr(version, '.') - 1)
from v$instance;

exit