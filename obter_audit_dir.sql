set newpage none pagesize 0 feed off head off trimspool on lines 2000 echo off
col value for a2000

select value
from v$parameter
where name = 'audit_file_dest';

exit