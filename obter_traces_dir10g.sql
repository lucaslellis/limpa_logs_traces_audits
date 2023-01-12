set newpage none pagesize 0 feed off head off trimspool on lines 2000 echo off serveroutput on
col value for a2000

select value
from v$parameter
where name in ('background_dump_dest', 'user_dump_dest');

exit