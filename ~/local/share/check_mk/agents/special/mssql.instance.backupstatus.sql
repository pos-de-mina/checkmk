set nocount on;
SELECT '<<<mssql_backupstatus:sep(124)>>>';

/* Validacao dos BACKUPS PARA BDs
	FULL:
		1. Verificar que todos os Full Backups foram efectuados com um intervalo <= 7 dias em relação a GETDATE();
	
	DIFERENCIAL:
	2. Verificar que o ultimo backup diferencial foi efectuado de acordo com os seguintes intervalos em relação a GETDATE();
		2.1. Se o backup diferencial tiver sido feito com intervalo > 1 dia e <= 2 dias, então NÃO é considerado critico;
		2.2. Se o backup diferencial tiver sido feito com intervalo > 2 dias então É considerado critico;
		
	T_LOG:
	3. Verificar que foram efectuados backups de acordo com as seguintes regras:
		3.1. SE backup anterior ao ultimo bckLOG (L) for Diferencial (I) E é 2ª feira ENTÃO o intervalo tem que ser <= 260 minutos.
		3.2. SE backup anterior ao ultimo bckLOG (L) for Diferencial (I) E NÃO é 2ª feira ENTÃO o intervalo tem que ser <= 500 minutos.
		3.3. SE backup anterior ao ultimo bckLOG (L) for Log (L) ENTÃO o intervalo tem que ser <= 250 minutos.
*/

SET DATEFIRST 7
--Primeiro dia da semana é domingo

IF OBJECT_ID('tempdb..#BACKUPS') IS NOT NULL
	DROP TABLE #BACKUPS

CREATE TABLE #BACKUPS
(
    database_id smallint,
    device_type tinyint,
    [type] varchar(5),
    backup_start_date datetime,
    RecoveryModel sql_variant
)

--Lista de Backups feitos pelo NetBackup com um intervalo <= 7 dias em relação a hoje:
--SQL 2000 não tem campo is_copy_only
IF CAST(SERVERPROPERTY('ProductVersion') AS varchar(50)) NOT LIKE '8%'
BEGIN
    EXEC('
			INSERT INTO #BACKUPS (database_id, device_type, [type], backup_start_date, RecoveryModel)
			SELECT DB_ID(bcks.database_name) AS database_id, bckMF.device_type, bckS.type, bckS.backup_start_date, DATABASEPROPERTYEX(bcks.database_name, ''recovery'') as RecoveryModel
			FROM  msdb.dbo.backupset bckS INNER JOIN msdb.dbo.backupmediaset bckMS
			ON bckS.media_set_id = bckMS.media_set_id
			INNER JOIN msdb.dbo.backupmediafamily bckMF 
			ON bckMS.media_set_id = bckMF.media_set_id
			WHERE bckS.is_copy_only = 0
			AND DATEDIFF(DD, bckS.backup_start_date, GETDATE()) <= 7 
			AND bckMF.device_type = 7 --Virtual Device
		')
END
ELSE
BEGIN
    EXEC('
		INSERT INTO #BACKUPS (database_id, device_type, [type], backup_start_date, RecoveryModel)
		SELECT DB_ID(bcks.database_name) AS database_id, bckMF.device_type, bckS.type, bckS.backup_start_date, DATABASEPROPERTYEX(bcks.database_name, ''recovery'') as RecoveryModel
		FROM  msdb.dbo.backupset bckS INNER JOIN msdb.dbo.backupmediaset bckMS
		ON bckS.media_set_id = bckMS.media_set_id
		INNER JOIN msdb.dbo.backupmediafamily bckMF 
		ON bckMS.media_set_id = bckMF.media_set_id
		WHERE DATEDIFF(DD, bckS.backup_start_date, GETDATE()) <= 7 
		AND bckMF.device_type = 7 --Virtual Device	
	')
END

--VALIDACAO DE FULLBACKUPS:
IF OBJECT_ID('tempdb..#FULL_BACKUPS') IS NOT NULL
	DROP TABLE #FULL_BACKUPS

--Lista dos ultimos FullBackups efectuados por BD:
SELECT database_id, MAX(backup_start_date) AS backup_start_date
INTO #FULL_BACKUPS
FROM #BACKUPS
WHERE type = 'D'
GROUP BY database_id


--VALIDACAO DE BACKUPS DIFERENCIAIS:
IF OBJECT_ID('tempdb..#DIF_BACKUPS') IS NOT NULL
	DROP TABLE #DIF_BACKUPS

--Lista dos ultimos backups diferenciais efectuados por BD, a partir das BDs que têm os Full OK:
--	SE intervalo <= 1 dias em relação GETDATE() ENTAO BCK_STATUS = 1 <=> OK
--	SE intervalo > 1 e <= 2 em relação a GETDATE() ENTAO BCK_STATUS = 2 <=> OK Parcial
--	ELSE NOT OK  
SELECT database_id, MAX(backup_start_date) AS backup_start_date, CASE WHEN DATEDIFF(DD, MAX(backup_start_date), GETDATE()) <= 1 THEN 1 ELSE 2 END AS BCK_STATUS
INTO #DIF_BACKUPS
FROM #BACKUPS
WHERE type = 'I'
    AND DATEDIFF(DD, backup_start_date, GETDATE()) <= 2
    AND database_id IN (SELECT database_id
    FROM #FULL_BACKUPS)
GROUP BY database_id


--VALIDACAO DE BACKUPS T_LOGS:
IF OBJECT_ID('tempdb..#VALID_LOG_BACKUPS') IS NOT NULL
	DROP TABLE #LAST_BACKUP, #VALID_LOG_BACKUPS

--Tabela que guarda os VALID_LOG_BACKUPS:
--BCK_STATUS = 1 <=> OK
--BCK_STATUS = 2 <=> OK Parcial
--ELSE NOT OK
CREATE TABLE #VALID_LOG_BACKUPS
(
    database_id int,
    BCK_STATUS int
)


--SE backup anterior ao ultimo bckLOG (L) for Diferencial (I) E é 2ª feira ENTÃO o intervalo tem que ser <= 260 minutos.
--SE backup anterior ao ultimo bckLOG (L) for Diferencial (I) E NÃO é 2ª feira ENTÃO o intervalo tem que ser <= 500 minutos.
--SE backup anterior ao ultimo bckLOG (L) for Log (L) ENTÃO o intervalo tem que ser <= 250 minutos.

--Criar uma tabela com os ultimos BCKs realizados a cada BD, cujo RM é diferente de SIMPLE:
SELECT database_id, [type] as UltimoBCK_type, backup_start_date as UltimoBCK_StartDate
INTO #LAST_BACKUP
FROM #BACKUPS B_OUT
WHERE RecoveryModel <> 'SIMPLE'
    AND backup_start_date = (SELECT MAX(B.backup_start_date)
    FROM #BACKUPS B
    WHERE B.database_id = B_OUT.database_id)

--Aplicar agora as regras:
INSERT INTO #VALID_LOG_BACKUPS
    (database_id, BCK_STATUS)
SELECT database_id,
    CASE 
			--Full ao domingo:
			WHEN UltimoBCK_type = 'D' AND DATEDIFF(MI,UltimoBCK_StartDate, GETDATE()) < 1700 THEN 1
			--Diferencial e Log à segunda-feira:
			WHEN UltimoBCK_type = 'I' AND DATEPART(weekday, UltimoBCK_StartDate) = 2 AND DATEDIFF(MI,UltimoBCK_StartDate,GETDATE()) <= 260 THEN 1
			--Diferencial e Log fora de segunda-feira:
			WHEN UltimoBCK_type = 'I' AND DATEPART(weekday, UltimoBCK_StartDate) <> 2 AND DATEDIFF(MI,UltimoBCK_StartDate,GETDATE()) <= 500 THEN 1
			--Log e Log:
			WHEN  UltimoBCK_type = 'L' AND DATEDIFF(MI,UltimoBCK_StartDate, GETDATE()) <= 250 THEN 1
			--Log e Log com o ultimo falhado e o penultimo ok
			WHEN UltimoBCK_type = 'L' AND DATEDIFF(MI,UltimoBCK_StartDate, GETDATE()) > 250 AND DATEDIFF(MI,UltimoBCK_StartDate, GETDATE()) <= 500 THEN 2
		END AS BCK_STATUS

FROM #LAST_BACKUP


--AlwaysOn: 
IF OBJECT_ID('tempdb..#ALWAYSON_REPLICA_ROLE_DESC') IS NOT NULL
	DROP TABLE #ALWAYSON_REPLICA_ROLE_DESC

CREATE TABLE #ALWAYSON_REPLICA_ROLE_DESC
(
    database_id int,
    name sysname,
    RoleDesc nvarchar(100)
)

IF CAST(SERVERPROPERTY('ProductVersion') AS varchar(50)) LIKE '11.%'
BEGIN

    INSERT INTO #ALWAYSON_REPLICA_ROLE_DESC
        (database_id, name, RoleDesc)
    SELECT d.dbid, d.name, ISNULL(ars.role_desc, 'PRIMARY') as RoleDesc
    FROM (master.dbo.sysdatabases d
        LEFT JOIN (sys.dm_hadr_database_replica_states DRS
        INNER JOIN sys.dm_hadr_availability_replica_states ARS
        ON DRS.group_id = ARS.group_id AND DRS.replica_id = ARS.replica_id)
        ON d.dbid = DRS.database_id)
    WHERE (ARS.is_local = 1) OR (DRS.database_id IS NULL)
END
ELSE
BEGIN
    INSERT INTO #ALWAYSON_REPLICA_ROLE_DESC
        (database_id, name, RoleDesc)
    SELECT d.dbid, d.name, 'PRIMARY' as RoleDesc
    FROM master.dbo.sysdatabases d
END


--Devolucao de Resultado:
IF OBJECT_ID('tempdb..#FINAL') IS NOT NULL
	DROP TABLE #FINAL


CREATE TABLE #FINAL
(
    database_id int,
    name sysname,
    RecoveryModelDesc nvarchar(100),
    BCK_STATUS_FULL int NULL,
    BCK_STATUS_DIF int NULL,
    BCK_STATUS_LOG int NULL,
    RoleDesc nvarchar(100) NULL,
    BackupsToDisk bit NULL
)

--Nota: a tempdb e a DBA_GIIT não são consideradas
INSERT INTO #FINAL
    (database_id, name, RecoveryModelDesc)
SELECT dbid, name, CAST(DATABASEPROPERTYEX(d.name, 'recovery') AS nvarchar(120))
FROM master.dbo.sysdatabases d
WHERE name NOT IN ('tempdb', 'DBA_GIIT')


--Juntar os estados dos BCKs:
UPDATE #FINAL SET BCK_STATUS_FULL = 1
FROM #FINAL INNER JOIN #FULL_BACKUPS
    ON #FINAL.database_id = #FULL_BACKUPS.database_id


UPDATE #FINAL SET BCK_STATUS_DIF = #DIF_BACKUPS.BCK_STATUS
FROM #FINAL INNER JOIN #DIF_BACKUPS
    ON #FINAL.database_id = #DIF_BACKUPS.database_id

UPDATE #FINAL SET BCK_STATUS_LOG = #VALID_LOG_BACKUPS.BCK_STATUS
FROM #FINAL INNER JOIN #VALID_LOG_BACKUPS
    ON #FINAL.database_id = #VALID_LOG_BACKUPS.database_id


--Juntar a componente de ALWAYSON:
UPDATE #FINAL SET RoleDesc = #ALWAYSON_REPLICA_ROLE_DESC.RoleDesc
FROM #FINAL INNER JOIN #ALWAYSON_REPLICA_ROLE_DESC
    ON #FINAL.database_id = #ALWAYSON_REPLICA_ROLE_DESC.database_id


--Juntar Verificacao de backups (Nao COPY_ONLY) para disco que comprometam a sequencia de backups (apenas para > SQL 2000):
IF CAST(SERVERPROPERTY('ProductVersion') AS varchar(50)) NOT LIKE '8%'
BEGIN
    EXEC( '
			UPDATE #FINAL SET BackupsToDisk = T_BCK_TO_DISK.BCK_TO_DISK
			FROM #FINAL INNER JOIN 
			(
				SELECT DISTINCT DB_ID(bcks.database_name) AS database_id, 1 AS BCK_TO_DISK
				FROM  msdb.dbo.backupset bckS INNER JOIN msdb.dbo.backupmediaset bckMS
				ON bckS.media_set_id = bckMS.media_set_id
				INNER JOIN msdb.dbo.backupmediafamily bckMF 
				ON bckMS.media_set_id = bckMF.media_set_id
				WHERE bckS.is_copy_only = 0
				AND DATEDIFF(DD, bckS.backup_start_date, GETDATE()) <= 7 
				AND bckMF.device_type = 2 --Disk
				AND bcks.backup_start_date > (SELECT MAX(backup_start_date) FROM #FULL_BACKUPS FB WHERE DB_ID(bcks.database_name) = FB.database_id)
			) T_BCK_TO_DISK
			ON #FINAL.database_id = T_BCK_TO_DISK.database_id
		')
END


--Query de Resultado:
SELECT 
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    BaseDados,
    CASE 
	WHEN BCK_STATUS_FULL = '' AND BCK_STATUS_DIF = '' AND BCK_STATUS_LOG = '' AND BCK_TO_DISK = '' THEN 'OK'
	WHEN BCK_STATUS_FULL = 'NA' AND BCK_STATUS_DIF = 'NA' AND BCK_STATUS_LOG = 'NA' THEN 'NA'
	ELSE BCK_STATUS_FULL + '  ' + BCK_STATUS_DIF + '  ' + BCK_STATUS_LOG + '  ' + BCK_TO_DISK
END AS EstadoBCKs

FROM
    (
SELECT name AS BaseDados, RecoveryModelDesc,
        --FULL:
        CASE 
	WHEN (RoleDesc = 'PRIMARY') AND (ISNULL(BCK_STATUS_FULL, 0) <> 1) THEN 'FALTA_BCK_FULL'
	WHEN (RoleDesc = 'SECONDARY') THEN 'NA'
	ELSE ''
END AS BCK_STATUS_FULL,

        --DIFs:
        CASE
	WHEN (RoleDesc = 'PRIMARY') AND (BCK_STATUS_DIF = 1 OR name = 'master') THEN ''
	WHEN (RoleDesc = 'PRIMARY') AND (ISNULL(BCK_STATUS_DIF, 0) NOT IN (1,2) AND name <> 'master') THEN 'FALTAM_BCKs_DIFERENCIAIS'
	WHEN (RoleDesc = 'SECONDARY') THEN 'NA'
	ELSE ''
END AS BCK_STATUS_DIF,

        --LOGS:
        CASE 
	WHEN (RoleDesc = 'PRIMARY') AND ((BCK_STATUS_LOG = 1) OR (RecoveryModelDesc = 'SIMPLE') OR (name IN ('master', 'model', 'msdb'))) THEN ''
	WHEN (RoleDesc = 'PRIMARY') AND (ISNULL(BCK_STATUS_LOG, 0) NOT IN (1,2) AND RecoveryModelDesc <> 'SIMPLE' AND name NOT IN ('master', 'model', 'msdb')) THEN 'FALTAM_BCKs_T_LOG'
	WHEN (RoleDesc = 'SECONDARY') THEN 'NA'
	ELSE ''
END AS BCK_STATUS_LOG,

        --BCKs TO DISK:
        CASE
	WHEN ISNULL(BackupsToDisk, 0) = 1 THEN 'BCKs_REALIZADOS_PARA_DISCO'
	ELSE ''
END AS BCK_TO_DISK

    FROM #FINAL
) RESULTADO_FINAL

SELECT '<<<>>>';
