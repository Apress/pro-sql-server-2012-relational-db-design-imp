CREATE DATABASE demonstrateFilegroups ON
PRIMARY ( NAME = Primary1, FILENAME = 'c:\sql\data\demonstrateFilegroups_primary.mdf',
          SIZE = 10MB),
FILEGROUP SECONDARY
        ( NAME = Secondary1,FILENAME = 
                            'c:\sql\data\demonstrateFilegroups_secondary1.ndf',
          SIZE = 10MB),
        ( NAME = Secondary2,FILENAME = 
                            'c:\sql\data\demonstrateFilegroups_secondary2.ndf',
          SIZE = 10MB)
LOG ON ( NAME = Log1,FILENAME = 'c:\sql\log\demonstrateFilegroups_log.ldf', SIZE = 10MB) ;

GO

CREATE DATABASE demonstrateFileGrowth ON
PRIMARY ( NAME = Primary1,FILENAME = 'c:\sql\data\demonstrateFileGrowth_primary.mdf',
                              SIZE = 1GB, FILEGROWTH=100MB, MAXSIZE=2GB)
LOG ON ( NAME = Log1,FILENAME = 'c:\sql\data\demonstrateFileGrowth_log.ldf', SIZE = 10MB);
GO



USE demonstrateFileGroups;
GO
SELECT case when fg.name is NULL 
                 then CONCAT('OTHER-',df.type_desc COLLATE database_default)
                        else fg.name end as file_group,
       df.name as file_logical_name,
       df.physical_name as physical_file_name
FROM   sys.filegroups fg
         RIGHT JOIN sys.database_files df
            ON fg.data_space_id = df.data_space_id;
GO


USE MASTER;
GO
DROP DATABASE demonstrateFileGroups;
GO
DROP DATABASE demonstrateFileGrowth;
GO





USE tempdb
GO
CREATE TABLE testCompression
(
    testCompressionId int NOT NULL,
    value  int NOT NULL
) 
WITH (DATA_COMPRESSION = ROW) -- PAGE or NONE
    ALTER TABLE testCompression REBUILD WITH (DATA_COMPRESSION = PAGE);

CREATE CLUSTERED INDEX XTestCompression_value
   ON testCompression (value) WITH ( DATA_COMPRESSION = ROW );

ALTER INDEX XTestCompression_value 
   ON testCompression REBUILD WITH ( DATA_COMPRESSION = PAGE );
GO 


--============================================

CREATE PARTITION FUNCTION PartitionFunction$dates (smalldatetime)
AS RANGE LEFT FOR VALUES ('20060101','20070101');  
                  --set based on recent version of 
                  --AdventureWorks2012 .Sales.SalesOrderHeader table to show
                  --partition utilization

GO


CREATE PARTITION SCHEME PartitonScheme$dates
                AS PARTITION PartitionFunction$dates ALL to ( [PRIMARY] );

GO


CREATE TABLE dbo.salesOrder
(
    salesOrderId     int NOT NULL,
    customerId       int  NOT NULL,
    orderAmount      decimal(10,2)  NOT NULL,
    orderDate        smalldatetime  NOT NULL,
    constraint PKsalesOrder primary key nonclustered (salesOrderId) 
                                                               ON [Primary],
    constraint AKsalesOrder unique clustered (salesOrderId, orderDate)
) on PartitonScheme$dates (orderDate );

GO

INSERT INTO dbo.salesOrder(salesOrderId, customerId, orderAmount, orderDate)
SELECT SalesOrderID, CustomerID, TotalDue, OrderDate
FROM   AdventureWorks2012.Sales.SalesOrderHeader;

GO

SELECT *, $partition.PartitionFunction$dates(orderDate) as partiton
FROM   dbo.salesOrder;

GO

SELECT  partitions.partition_number, partitions.index_id, 
        partitions.rows, indexes.name, indexes.type_desc
FROM    sys.partitions as partitions
           JOIN sys.indexes as indexes
               on indexes.object_id = partitions.object_id
                   and indexes.index_id = partitions.index_id
WHERE   partitions.object_id = object_id('dbo.salesOrder');

-====================================
GO
Use TempDb
GO


CREATE SCHEMA produce;
GO
CREATE TABLE produce.vegetable
(
   --PK constraint defaults to clustered
   vegetableId int NOT NULL CONSTRAINT PKproduce_vegetable PRIMARY KEY,
   name varchar(15) NOT NULL 
                   CONSTRAINT AKproduce_vegetable_name UNIQUE,

   color varchar(10) NOT NULL,
   consistency varchar(10) NOT NULL,
   filler char(4000) default (replicate('a', 4000)) NOT NULL 
);



GO



CREATE INDEX Xproduce_vegetable_color ON produce.vegetable(color);
CREATE INDEX Xproduce_vegetable_consistency ON produce.vegetable(consistency);

GO


CREATE UNIQUE INDEX Xproduce_vegetable_vegetableId_color
        ON produce.vegetable(vegetableId, color);
GO


INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (1,'carrot','orange','crunchy'), (2,'broccoli','green','leafy'),
       (3,'mushroom','brown','squishy'), (4,'pea','green','squishy'),
       (5,'asparagus','green','crunchy'), (6,'sprouts','green','leafy'),
       (7,'lettuce','green','leafy'),( 8,'brussels sprout','green','leafy'),
       (9,'spinach','green','leafy'), (10,'pumpkin','orange','solid'),
       (11,'cucumber','green','solid'), (12,'bell pepper','green','solid'),
       (13,'squash','yellow','squishy'), (14,'canteloupe','orange','squishy'),
       (15,'onion','white','solid'), (16,'garlic','white','solid');

GO

SELECT  name, type_desc, is_unique
FROM    sys.indexes
WHERE   OBJECT_ID('produce.vegetable') = object_id;
GO


DROP INDEX Xproduce_vegetable_consistency ON produce.vegetable ;
GO



SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable;
GO
SET SHOWPLAN_TEXT OFF;
GO

GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4;
Go
SET SHOWPLAN_TEXT OFF;
GO


SET STATISTICS IO ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId in (1,4);
Go
SET STATISTICS IO OFF ; 
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4;
GO
SET SHOWPLAN_TEXT OFF;

GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId >  4;
GO
SET SHOWPLAN_TEXT OFF;
GO

SELECT OBJECT_NAME(i.object_id) as object_name
      , CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
                i.TYPE_DESC as index_type
      , i.name as index_name
      , user_seeks, user_scans, user_lookups,user_updates
FROM  sys.indexes i 
         LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s 
              ON i.object_id = s.object_id 
                AND i.index_id = s.index_id 
                AND database_id = db_id()
WHERE  OBJECTPROPERTY(i.object_id , 'IsUserTable') = 1 
ORDER  BY 1,3;
GO

--=====================================================

DBCC SHOW_STATISTICS('AdventureWorks2012.Production.WorkOrder', 
                          'IX_WorkOrder_ProductID') WITH DENSITY_VECTOR;
DBCC SHOW_STATISTICS('AdventureWorks2012.Production.WorkOrder', 
                          'IX_WorkOrder_ProductID') WITH HISTOGRAM;


--Used isnull as it is easier if the column can be null
--value you translate to should be impossible for the column
--ProductId is an identity with seed of 1 and increment of 1
--so this should be safe (unless a dba does something weird)
SELECT 1.0/ COUNT(DISTINCT ISNULL(ProductID,-1)) AS density,
            COUNT(DISTINCT ISNULL(ProductID,-1))  AS distinctRowCount,
            1.0/ count(*) as uniqueDensity,
            COUNT(*) as allRowCount
FROM   AdventureWorks2012.Production.WorkOrder;

GO

CREATE TABLE testIndex
(
    testIndex int NOT NULL IDENTITY(1,1) CONSTRAINT PKtestIndex PRIMARY KEY,
    bitValue bit NOT NULL,
    filler char(2000) NOT NULL DEFAULT (replicate('A',2000))
);
CREATE INDEX XtestIndex_bitValue ON testIndex(bitValue);
GO
SET NOCOUNT ON;
INSERT INTO testIndex(bitValue)
VALUES (0);
GO 50000 --runs current batch 5 0000 times in Management Studio.
INSERT INTO testIndex(bitValue)
VALUES (1);
GO 100 --puts 100 rows into table with value 1 



SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   testIndex
WHERE  bitValue = 0 ;
GO
SET SHOWPLAN_TEXT OFF
GO


SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   testIndex
WHERE  bitValue = 1

Go
SET SHOWPLAN_TEXT OFF
GO

UPDATE STATISTICS dbo.testIndex 
DBCC SHOW_STATISTICS('dbo.testIndex', 'XtestIndex_bitValue')  WITH HISTOGRAM;
GO

CREATE INDEX XtestIndex_bitValueOneOnly 
      ON testIndex(bitValue) WHERE bitValue = 1; 
GO

DBCC SHOW_STATISTICS('dbo.testIndex', 'XtestIndex_bitValueOneOnly') 
                                                WITH HISTOGRAM;
GO

--=================================================


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4;
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId < 3;
GO
SET SHOWPLAN_TEXT OFF;
GO

--===================================================================


SET SHOWPLAN_TEXT ON;
GO
SELECT vegetableId, name, color, consistency 
FROM produce.vegetable
WHERE color = 'green'
  AND consistency = 'crunchy ';
GO
SET SHOWPLAN_TEXT OFF;
GO


SELECT color, consistency, count(*) as [count]
FROM   produce.vegetable
GROUP BY color, consistency
ORDER BY color, consistency;
GO

SELECT COUNT(Distinct color) as color,
       COUNT(Distinct consistency) as consistency
FROM   produce.vegetable;
GO
CREATE INDEX Xproduce_vegetable_consistencyAndColor
         ON produce.vegetable(consistency, color);
GO

SET SHOWPLAN_TEXT ON
GO
SELECT vegetableId, name, color, consistency 
FROM produce.vegetable
WHERE color = 'green'
  and consistency = 'crunchy'

Go
SET SHOWPLAN_TEXT OFF
GO


SET SHOWPLAN_TEXT ON
GO
select name, color
from produce.vegetable
where color = 'green'
Go
SET SHOWPLAN_TEXT OFF
GO

DROP INDEX Xproduce_vegetable_color ON produce.vegetable;
CREATE INDEX Xproduce_vegetable_color ON produce.vegetable(color) INCLUDE (name);

GO

SET SHOWPLAN_TEXT ON
GO
select name, color
from produce.vegetable
where color = 'green'
Go
SET SHOWPLAN_TEXT OFF
GO


CREATE INDEX Xproduce_vegetable_consistency ON produce.vegetable(consistency);
--existing index repeated as a reminder
--CREATE INDEX Xproduce_vegetable_color ON produce.vegetable(color) INCLUDE (name);

GO
SET SHOWPLAN_TEXT ON
GO
SELECT consistency, color
FROM   produce.vegetable with (index=Xproduce_vegetable_color,
                             index=Xproduce_vegetable_consistency)
WHERE  color = 'green'
 and   consistency = 'leafy';
Go
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO
SELECT MaritalStatus, HireDate
FROM   Adventureworks2012.HumanResources.Employee
ORDER BY MaritalStatus ASC, HireDate DESC
Go
SET SHOWPLAN_TEXT OFF
GO

 CREATE INDEX Xemployee_maritalStatus_hireDate ON 
       Adventureworks2012.HumanResources.Employee (MaritalStatus,HireDate) ;

GO

SET SHOWPLAN_TEXT ON
GO
SELECT MaritalStatus, HireDate
FROM   Adventureworks2012.HumanResources.Employee
ORDER BY MaritalStatus ASC, HireDate DESC

Go
SET SHOWPLAN_TEXT OFF
GO

GO

DROP INDEX Xemployee_maritalStatus_hireDate ON 
        Adventureworks2012.HumanResources.Employee
GO
CREATE INDEX Xemployee_maritalStatus_hireDate ON 
    AdventureWorks2012.HumanResources.Employee(MaritalStatus ASC,HireDate DESC )


GO
SET SHOWPLAN_TEXT ON
GO
SELECT MaritalStatus, HireDate
FROM   Adventureworks2012.HumanResources.Employee
ORDER BY MaritalStatus ASC, HireDate DESC

Go
SET SHOWPLAN_TEXT OFF
GO

--=================================

ALTER TABLE produce.vegetable
    DROP CONSTRAINT PKproduce_vegetable;

ALTER TABLE produce.vegetable
    ADD CONSTRAINT PKproduce_vegetable PRIMARY KEY NONCLUSTERED (vegetableID);

GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4;
Go
SET SHOWPLAN_TEXT OFF;
GO

--====================================================

USE AdventureWorks2012;
GO
CREATE VIEW Production.ProductAverageSales
WITH SCHEMABINDING
AS
SELECT Product.ProductNumber,
       SUM (SalesOrderDetail.LineTotal) as TotalSales,
       COUNT_BIG(*) as CountSales --must use COUNT_BIG for indexed view
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON Product.ProductID=SalesOrderDetail.ProductID
GROUP  BY Product.ProductNumber;

GO

SET SHOWPLAN_TEXT ON;
GO

SELECT ProductNumber, TotalSales, CountSales
FROM   Production.ProductAverageSales ;

Go
SET SHOWPLAN_TEXT OFF;
GO
CREATE UNIQUE CLUSTERED INDEX XPKProductAverageSales on
                      Production.ProductAverageSales(ProductNumber);

GO

SET SHOWPLAN_TEXT ON
GO

SELECT ProductNumber, TotalSales, CountSales 
FROM   Production.ProductAverageSales;

Go
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO

SELECT Product.ProductNumber, SUM(SalesOrderDetail.LineTotal) / COUNT(*)
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON Product.ProductID=SalesOrderDetail.ProductID 
GROUP  BY Product.ProductNumber;

GO
SET SHOWPLAN_TEXT OFF
GO

--==============================
SELECT ddmid.statement AS object_name, ddmid.equality_columns, ddmid.inequality_columns, 
       ddmid.included_columns,  ddmigs.user_seeks, ddmigs.user_scans, 
       ddmigs.last_user_seek, ddmigs.last_user_scan, ddmigs.avg_total_user_cost,
       ddmigs.avg_user_impact, ddmigs.unique_compiles 
FROM   sys.dm_db_missing_index_groups ddmig
         JOIN sys.dm_db_missing_index_group_stats ddmigs
                ON ddmig.index_group_handle = ddmigs.group_handle
         JOIN sys.dm_db_missing_index_details ddmid
                ON ddmid.index_handle = ddmig.index_handle
ORDER BY ((user_seeks + user_scans) * avg_total_user_cost * (avg_user_impact * 0.01)) DESC;


GO



SELECT OBJECT_SCHEMA_NAME(indexes.object_id) + '.' +
       OBJECT_NAME(indexes.object_id) as objectName,
       indexes.name, 
       case when is_unique = 1 then 'UNIQUE ' 
              else '' end + indexes.type_desc as index_type, 
       ddius.user_seeks, ddius.user_scans, ddius.user_lookups, 
       ddius.user_updates, last_user_lookup, last_user_scan, last_user_seek,last_user_update
FROM   sys.indexes
          LEFT OUTER JOIN sys.dm_db_index_usage_stats ddius
               ON indexes.object_id = ddius.object_id
                   AND indexes.index_id = ddius.index_id
                   AND ddius.database_id = db_id()
ORDER  BY ddius.user_seeks + ddius.user_scans + ddius.user_lookups DESC;
GO

SELECT  s.[name] AS SchemaName,
        o.[name] AS TableName,
        i.[name] AS IndexName,
        f.[avg_fragmentation_in_percent] AS FragPercent,
        f.fragment_count ,
        f.forwarded_record_count --heap only
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, DEFAULT) f
        JOIN sys.indexes i 
             ON f.[object_id] = i.[object_id] AND f.[index_id] = i.[index_id]
        JOIN sys.objects o 
             ON i.[object_id] = o.[object_id]
        JOIN sys.schemas s 
             ON o.[schema_id] = s.[schema_id]
WHERE o.[is_ms_shipped] = 0
  AND i.[is_disabled] = 0; -- skip disabled indexes
