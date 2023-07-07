/*
 * MSSQL blocked Sessions
 */
set nocount on;

SELECT 
    ISNULL(SERVERPROPERTY('InstanceName'),'MSSQLSERVER'),
    session_id, 
    wait_duration_ms, 
    wait_type, 
    blocking_session_id 
FROM 
    sys.dm_os_waiting_tasks 
WHERE 
    blocking_session_id <> 0; 

-- test if no records found
if (@@rowcount = 0) begin
    SELECT 
        ISNULL(SERVERPROPERTY('InstanceName'),'MSSQLSERVER'),
        'No blocking sessions';
end
