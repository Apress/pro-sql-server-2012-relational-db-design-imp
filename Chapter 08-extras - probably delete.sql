CREATE  DATABASE FileStorageDemo; --uses basic defaults from model databases
GO
USE FileStorageDemo;
GO


CREATE TABLE dbo.FileTableTest2 AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	FILETABLE_COLLATE_FILENAME = database_default
	)
GO
Msg 1969, Level 16, State 1, Line 1
Default FILESTREAM filegroup is not available in database 'FileStorageDemo'.

--will cover more in the structures chapter
ALTER DATABASE FileStorageDemo ADD
	FILEGROUP FilestreamData CONTAINS FILESTREAM;

CREATE TABLE dbo.FileTableTest2 AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	FILETABLE_COLLATE_FILENAME = database_default
	)
GO

Msg 1719, Level 16, State 1, Line 1
FILESTREAM data cannot be placed on an empty filegroup.

Go
ALTER DATABASE FileStorageDemo ADD FILE (
       NAME = FilestreamDataFile1,
       FILENAME = 'c:\sql\filestream')
TO FILEGROUP FilestreamData;
GO

CREATE TABLE dbo.FileTableTest2 AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	FILETABLE_COLLATE_FILENAME = database_default
	)
GO

ALTER DATABASE [FileStorageDemo] SET FILESTREAM( DIRECTORY_NAME = N'FileStorageDemo' ) WITH NO_WAIT
GO

CREATE TABLE dbo.FileTableTest2 AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	FILETABLE_COLLATE_FILENAME = database_default
	)
GO
