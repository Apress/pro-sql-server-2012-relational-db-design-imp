Use tempdb
go
;WITH digits (I) 
     as(--set up a set of numbers from 0-9
              SELECT I
              FROM  (VALUES (0),(1),(2),(3),(4),
                            (5),(6),(7),(8),(9)) as digits (I))
,integers (I) as (
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I)
              -- + (10000*D5.I) + (100000*D6.I)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4
              --CROSS JOIN digits AS D5 CROSS JOIN digits AS D6
                )
SELECT I
FROM   integers
ORDER  BY I;
GO


;WITH digits (I) as(--set up a set of numbers from 0-9
        SELECT i
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (I))
SELECT D1.I as D1I, 10*D2.I as D2I, D1.I + (10*D2.I) as [Sum]
FROM digits AS D1 CROSS JOIN digits AS D2
ORDER BY [Sum];
GO

---=============================
--- Side Example
---=============================

--Interesting, but a bit slower
--Tom Øyvind Hogstad  http://codenet.blogspot.com/2006/06/sql-numbers-table-using-common-table.html
WITH Numbers(n)
AS
(
SELECT 1 AS n
UNION ALL
SELECT (n + 1) AS n
FROM Numbers
WHERE
n < 1000000
)
SELECT n from Numbers
OPTION(MAXRECURSION 0) -- defaults 100
go

---=============================
--- Side Example - END
---=============================

USE AdventureWorks2012;
GO
CREATE SCHEMA Tools;
GO
CREATE TABLE Tools.Number
(
    I   int CONSTRAINT PKTools_Number PRIMARY KEY
);
GO


;WITH DIGITS (I) as(--set up a set of numbers from 0-9
        SELECT I
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (I))
--builds a table from 0 to 99999
,Integers (I) as (
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I) + (10000*D5.I)
               --+ (100000*D6.I)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                /* CROSS JOIN digits AS D6 */)
INSERT INTO Tools.Number(I)
SELECT I
FROM   Integers;

GO

SELECT COUNT(*) 
FROM   Tools.Number 
WHERE  I between 1 and 1000;

GO

SELECT COUNT(*) 
FROM  Tools.Number 
WHERE  I BETWEEN 1 AND 1000
  AND  (I % 9 = 0 OR I % 7 = 0 );

GO


DECLARE @string varchar(20) = 'Hello nurse!'

SELECT Number.I as Position,
       SUBSTRING(split.value,Number.I,1) as [Character],
       UNICODE(SUBSTRING(split.value,Number.I,1)) as [Unicode]
FROM   Tools.Number
         CROSS JOIN (select @string as value) as split
WHERE  Number.I > 0 --No zeroth  position
  AND  Number.I <= LEN(@string)
ORDER BY Position;
GO



SELECT LastName, Number.I as position,
              SUBSTRING(Person.LastName,Number.I,1) as [char],
              UNICODE(SUBSTRING(Person.LastName, Number.I,1)) as [Unicode]
FROM   /*Adventureworks2012.*/ Person.Person
         JOIN Tools.Number
               ON Number.I <= LEN(Person.LastName )
                   AND  UNICODE(SUBSTRING(Person.LastName, Number.I,1)) is not null
ORDER  BY LastName ;

GO


SELECT LastName, Number.I as Position,
              SUBSTRING(Person.LastName,Number.I,1) as [Char],
              UNICODE(SUBSTRING(Person.LastName, Number.I,1)) as [Unicode]
FROM   /*Adventureworks2012.*/ Person.Person
         JOIN Tools.Number
               ON Number.I <= LEN(Person.LastName )
                  AND  UNICODE(SUBSTRING(Person.LastName, Number.I,1)) is not null
--Note I used both a-z and A-Z in LIKE in case of case sensitive AW database
WHERE  SUBSTRING(Person.LastName, Number.I,1) not like '[a-zA-Z ~''~-]' ESCAPE '~'
ORDER BY LastName, Position ;
GO


SELECT  MIN(BusinessEntityID) AS MinValue, MAX(BusinessEntityID) AS MaxValue,
	MAX(BusinessEntityID) - MIN(BusinessEntityID) + 1 AS ExpectedNumberOfRows, 
	COUNT(*) AS NumberOfRows,
	MAX(BusinessEntityID) - COUNT(*) as MissingRows
FROM    /*Adventureworks2012.*/ Person.Person;
GO

SELECT Number.I
FROM   Tools.Number
WHERE  I between 1 and 20777
EXCEPT 
SELECT BusinessEntityID
FROM   /*Adventureworks2012.*/ Person.Person ;
GO



DECLARE @delimitedList VARCHAR(100) = '1,2,3'

SELECT SUBSTRING(',' + @delimitedList + ',',I + 1,
          CHARINDEX(',',',' + @delimitedList + ',',I + 1) - I - 1) as value
FROM Tools.Number
WHERE I >= 1 
  AND I < LEN(',' + @delimitedList + ',') - 1
  AND SUBSTRING(',' + @delimitedList + ',', I, 1) = ','
ORDER BY I ;
GO


DECLARE @delimitedList VARCHAR(100) = '1,2,3';

SELECT I
FROM Tools.Number
WHERE I >= 1
  AND I < LEN(',' + @delimitedList + ',') - 1
  AND SUBSTRING(',' + @delimitedList + ',', I, 1) = ','
ORDER BY I ;
GO


CREATE TABLE dbo.poorDesign
(
    poorDesignId    int,
    badValue        varchar(20)
);
INSERT INTO dbo.poorDesign
VALUES (1,'1,3,56,7,3,6'),
       (2,'22,3'),
       (3,'1');
GO


SELECT poorDesign.poorDesignId as betterDesignId,
       SUBSTRING(',' + poorDesign.badValue + ',',I + 1,
               CHARINDEX(',',',' + poorDesign.badValue + ',', I + 1) - I - 1)
                                       AS betterScalarValue
FROM   dbo.poorDesign
         JOIN Tools.Number
            on I >= 1
              AND I < LEN(',' + poorDesign.badValue + ',') - 1
              AND SUBSTRING(',' + + poorDesign.badValue  + ',', I, 1) = ',';
GO



DROP TABLE dbo.poorDesign;
GO


ALTER TABLE Tools.Number
  ADD Ipower3 as cast( power(cast(I as bigint),3) as bigint) PERSISTED  ;
  --Note that I had to cast I as bigint first to let the power function
  --return a bigint

GO

DECLARE @level int = 2; --sum of two cubes
;WITH cubes as
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 and I < 500) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 as [sum of 2 cubes in @level Ways]
FROM   cubes as c1
         cross join cubes as c2
WHERE c1.Ipower3 <= c2.Ipower3 --this gets rid of the "duplicate" value pairs

GROUP by (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];
GO


DECLARE @level int = 3; --sum of two cubes
;WITH cubes as
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 and I < 500) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 as [sum of 2 cubes in @level Ways]
FROM   cubes as c1
         cross join cubes as c2
WHERE c1.Ipower3 < c2.Ipower3
GROUP by (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];
GO

CREATE TABLE Tools.Calendar
(
        DateValue date NOT NULL CONSTRAINT PKtools_calendar PRIMARY KEY,
        DayName varchar(10) NOT NULL,
        MonthName varchar(10) NOT NULL,
        Year varchar(60) NOT NULL,
        Day tinyint NOT NULL,
        DayOfTheYear smallint NOT NULL,
        Month smallint NOT NULL,
        Quarter tinyint NOT NULL
);
GO


WITH dates (newDateValue) as (
        SELECT DATEADD(day,I,'17530101') as newDateValue
        FROM Tools.Number 
)
INSERT Tools.Calendar
        (DateValue ,DayName
        ,MonthName ,Year ,Day
        ,DayOfTheYear ,Month ,Quarter
)
SELECT
        dates.newDateValue as DateValue,
        DATENAME (dw,dates.newDateValue) as DayName,
        DATENAME (mm,dates.newDateValue) as MonthName,
        DATENAME (yy,dates.newDateValue) as Year,
        DATEPART(day,dates.newDateValue) as Day,
        DATEPART(dy,dates.newDateValue) as DayOfTheYear,
        DATEPART(m,dates.newDateValue) as Month,
        DATEPART(qq,dates.newDateValue) as Quarter

FROM    dates
WHERE   dates.newDateValue BETWEEN '20000101' AND '20130101' --set the date range
ORDER   BY DateValue;
GO

SELECT Calendar.Year, COUNT(*) as OrderCount
FROM   /*Adventureworks2012.*/ Sales.SalesOrderHeader
         JOIN Tools.Calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where possible
            ON CAST(SalesOrderHeader.OrderDate as date) = Calendar.DateValue
GROUP BY Calendar.Year
ORDER BY Calendar.Year ;
GO


SELECT Calendar.DayName, COUNT(*) as OrderCount
FROM   /*Adventureworks2012.*/ Sales.SalesOrderHeader
         JOIN Tools.Calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where
            ON CAST(SalesOrderHeader.OrderDate as date) = Calendar.DateValue 
WHERE Calendar.DayName in ('Tuesday','Thursday')
GROUP BY Calendar.DayName
ORDER BY Calendar.DayName;
GO

;WITH onlyWednesdays as --get all Wednesdays
(
    SELECT *,
           ROW_NUMBER()  OVER (PARTITION BY Calendar.Year, Calendar.Month
                               ORDER BY Calendar.Day) as wedRowNbr
    FROM   Tools.Calendar
    WHERE  DayName = 'Wednesday'
),
secondWednesdays as --limit to second Wednesdays of the month
(
    SELECT *
    FROM   onlyWednesdays
    WHERE  wedRowNbr = 2
)
,finallyTuesdays as --finally limit to the Tuesdays after the second wed
(
    SELECT Calendar.*,
           ROW_NUMBER() OVER (PARTITION BY Calendar.Year, Calendar.Month
                              ORDER by Calendar.Day) as rowNbr
    FROM   secondWednesdays
             JOIN Tools.Calendar
                ON secondWednesdays.Year = Calendar.Year
                    AND secondWednesdays.Month = Calendar.Month
    WHERE  Calendar.DayName = 'Tuesday'
      AND  Calendar.Day > secondWednesdays.Day
)
--and in the final query, just get the one month
SELECT Year, MonthName, Day
FROM   finallyTuesdays
WHERE  Year = 2012
  AND  rowNbr = 1;
GO

DROP TABLE Tools.Calendar
GO
CREATE TABLE Tools.Calendar
(
        DateValue date NOT NULL CONSTRAINT PKtools_calendar PRIMARY KEY,
        DayName varchar(10) NOT NULL,
        MonthName varchar(10) NOT NULL,
        Year varchar(60) NOT NULL,
        Day tinyint NOT NULL,
        DayOfTheYear smallint NOT NULL,
        Month smallint NOT NULL,
        Quarter tinyint NOT NULL,
	WeekendFlag bit NOT NULL,

        --start of fiscal year configurable in the load process, currently
        --only supports fiscal months that match the calendar months.
        FiscalYear smallint NOT NULL,
        FiscalMonth tinyint NULL,
        FiscalQuarter tinyint NOT NULL,

        --used to give relative positioning, such as the previous 10 months
        --which can be annoying due to month boundaries
        RelativeDayCount int NOT NULL,
        RelativeWeekCount int NOT NULL,
        RelativeMonthCount int NOT NULL
)
GO



;WITH dates (newDateValue) as (
        SELECT DATEADD(day,I,'17530101') as newDateValue
        FROM Tools.Number
)
INSERT Tools.Calendar
        (DateValue ,DayName
        ,MonthName ,Year ,Day
        ,DayOfTheYear ,Month ,Quarter
        ,WeekendFlag ,FiscalYear ,FiscalMonth
        ,FiscalQuarter ,RelativeDayCount,RelativeWeekCount
        ,RelativeMonthCount)
SELECT
        dates.newDateValue as DateValue,
        DATENAME (dw,dates.newDateValue) as DayName,
        DATENAME (mm,dates.newDateValue) as MonthName,
        DATENAME (yy,dates.newDateValue) as Year,
        DATEPART(day,dates.newDateValue) as Day,
        DATEPART(dy,dates.newDateValue) as DayOfTheYear,
        DATEPART(m,dates.newDateValue) as Month,
        CASE
                WHEN MONTH( dates.newDateValue) <= 3 THEN 1
                WHEN MONTH( dates.newDateValue) <= 6 THEN 2
                When MONTH( dates.newDateValue) <= 9 THEN 3
        Else 4 End AS quarter,

        CASE WHEN DATENAME (dw,dates.newDateValue) IN ('Saturday','Sunday')
                THEN 1
                ELSE 0
        END AS weekendFlag,

        ------------------------------------------------
        --the next three blocks assume a fiscal year starting in July.
        --change if your fiscal periods are different
        ------------------------------------------------
        CASE
                WHEN MONTH(dates.newDateValue) <= 6
                THEN YEAR(dates.newDateValue)
                ELSE YEAR (dates.newDateValue) + 1
        END AS fiscalYear,

        CASE
                WHEN MONTH(dates.newDateValue) <= 6
                THEN MONTH(dates.newDateValue) + 6
                ELSE MONTH(dates.newDateValue) - 6
         END AS fiscalMonth,

        CASE
                WHEN MONTH(dates.newDateValue) <= 3 then 3
                WHEN MONTH(dates.newDateValue) <= 6 then 4
                WHEN MONTH(dates.newDateValue) <= 9 then 1
        ELSE 2 end AS fiscalQuarter,

        ------------------------------------------------
        --end of fiscal quarter = july
        ------------------------------------------------

        --these values can be anything, as long as they
        --provide contiguous values on year, month, and week boundaries
        DATEDIFF(day,'20000101',dates.newDateValue) as RelativeDayCount,
        DATEDIFF(week,'20000101',dates.newDateValue) as RelativeWeekCount,
        DATEDIFF(month,'20000101',dates.newDateValue) as RelativeMonthCount

FROM    dates
WHERE  dates.newDateValue between '20000101' and '20130101'; --set the date range 
GO


SELECT Calendar.FiscalYear, COUNT(*) as OrderCount
FROM   /*Adventureworks2012.*/ Sales.SalesOrderHeader
         JOIN Tools.Calendar
               --note, the cast here could be a real performance killer
               --consider using a persisted calculated column here
            ON CAST(SalesOrderHeader.OrderDate as date) = Calendar.DateValue
WHERE    WeekendFlag = 1
GROUP BY Calendar.FiscalYear
ORDER BY Calendar.FiscalYear;
GO

DECLARE @interestingDate date = '20120509'

SELECT Calendar.DateValue as PreviousTwoWeeks, CurrentDate.DateValue as Today,
        Calendar.RelativeWeekCount
FROM   Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
              on  Calendar.RelativeWeekCount < (CurrentDate.RelativeWeekCount)
                  and Calendar.RelativeWeekCount >=
                                         (CurrentDate.RelativeWeekCount -2);
GO

DECLARE @interestingDate date = '20080315'

SELECT MIN(Calendar.DateValue) as MinDate, MAX(Calendar.DateValue) as MaxDate
FROM   Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
              ON  Calendar.RelativeMonthCount < (CurrentDate.RelativeMonthCount)
                  AND Calendar.RelativeMonthCount >=
                                       (CurrentDate.RelativeMonthCount -12);


GO

DECLARE @interestingDate date = '20120509'

SELECT MIN(Calendar.DateValue) as MinDate, MAX(Calendar.DateValue) as MaxDate
FROM   Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
              ON  Calendar.RelativeMonthCount < (CurrentDate.RelativeMonthCount)
                  AND Calendar.RelativeMonthCount >=
                                       (CurrentDate.RelativeMonthCount -12);
GO


DECLARE @interestingDate date = '20080927'

SELECT Calendar.Year, Calendar.Month, COUNT(*) as OrderCount
FROM   /*Adventureworks2012.*/ Sales.SalesOrderHeader
         JOIN Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
                   ON  Calendar.RelativeMonthCount <=
                                           (CurrentDate.RelativeMonthCount )
                    AND Calendar.RelativeMonthCount >=
                                           (CurrentDate.RelativeMonthCount -10)
            ON cast(SalesOrderHeader.ShipDate as date)= Calendar.DateValue
GROUP BY Calendar.Year, Calendar.Month
ORDER BY Calendar.Year, Calendar.Month;
GO


CREATE SCHEMA Monitor;
GO
CREATE TABLE Monitor.TableRowCount
(
	SchemaName  sysname NOT NULL,
	TableName	sysname NOT NULL,
	CaptureDate date    NOT NULL,
	Rows    	integer NOT NULL,
	ObjectType	sysname NOT NULL,
	Constraint PKMonitor_TableRowCount PRIMARY KEY (SchemaName, TableName, CaptureDate)
);
GO

CREATE PROCEDURE Monitor.TableRowCount$captureRowcounts
AS
-- ----------------------------------------------------------------
-- Monitor the row counts of all tables in the database on a daily basis
-- Error handling not included for example clarity
--
-- 2012 Louis Davidson – drsql@hotmail.com – drsql.org
-- ----------------------------------------------------------------

-- The CTE is used to set upthe set of rows to put into the Monitor.TableRowCount table
WITH CurrentRowcount as (
SELECT object_schema_name(partitions.object_id) AS SchemaName, 
	   object_name(partitions.object_id) AS TableName, 
	   cast(getdate() as date) AS CaptureDate,
	   sum(rows) AS Rows,
	   objects.type_desc AS ObjectType
FROM   sys.partitions
          JOIN sys.objects	
               ON partitions.object_id = objects.object_id
WHERE  index_id in (0,1) --Heap 0 or Clustered 1 “indexes”
AND    object_schema_name(partitions.object_id) NOT IN ('sys')
--the GROUP BY handles partitioned tables with > 1 partition
GROUP BY partitions.object_id, objects.type_desc)

--MERGE allows this procedure to be run > 1 a day without concern, it will update if the row
--for the day exists
MERGE  Monitor.TableRowCount
USING  (SELECT SchemaName, TableName, CaptureDate, Rows, ObjectType 
        FROM CurrentRowcount) AS Source 
        ON (Source.SchemaName = TableRowCount.SchemaName
			and Source.TableName = TableRowCount.TableName
			and Source.CaptureDate = TableRowCount.CaptureDate)
WHEN MATCHED THEN  
	UPDATE SET Rows = Source.Rows
WHEN NOT MATCHED THEN
	INSERT (SchemaName, TableName, CaptureDate, Rows, ObjectType) 
	VALUES (Source.SchemaName, Source.TableName, Source.CaptureDate, 
                Source.Rows, Source.ObjectType);
GO


EXEC Monitor.TableRowCount$captureRowcounts;

SELECT *
FROM   Monitor.TableRowCount
WHERE  SchemaName = 'HumanResources'
ORDER BY SchemaName, TableName
GO



CREATE SCHEMA Utility;
GO
CREATE PROCEDURE Utility.Constraints$ResetEnableAndTrustedStatus
(
    @table_name sysname = '%', 
    @table_schema sysname = '%',
    @doForeignKeyFlag bit = 1,
    @doCheckFlag bit = 1
) as
-- ----------------------------------------------------------------
-- Enables disabled foreign key and check constraints, and sets
-- trusted status so optimizer can use them
--
-- 2012 Louis Davidson – drsql@hotmail.com – drsql.org 
-- ----------------------------------------------------------------

 BEGIN
 
      SET NOCOUNT ON;
      DECLARE @statements cursor; --use to loop through constraints to execute one 
                                 --constraint for individual DDL calls
      SET @statements = cursor for 
           WITH FKandCHK AS (SELECT OBJECT_SCHEMA_NAME(parent_object_id) AS schemaName,                                       
                                    OBJECT_NAME(parent_object_id) AS tableName,
                                    NAME AS constraintName, Type_desc AS constraintType, 
                                    is_disabled AS DisabledFlag, 
                                    (is_not_trusted + 1) % 2 AS TrustedFlag
                             FROM   sys.foreign_keys
                             UNION ALL 
                             SELECT OBJECT_SCHEMA_NAME(parent_object_id) AS schemaName, 
                                    OBJECT_NAME(parent_object_id) AS tableName,
                                    NAME AS constraintName, Type_desc AS constraintType, 
                                    is_disabled AS DisabledFlag, 
                                    (is_not_trusted + 1) % 2 AS TrustedFlag
                             FROM   sys.check_constraints )
           SELECT schemaName, tableName, constraintName, constraintType, 
                  DisabledFlag, TrustedFlag 
           FROM   FKandCHK
           WHERE  (TrustedFlag = 0 OR DisabledFlag = 1)
             AND  ((constraintType = 'FOREIGN_KEY_CONSTRAINT' AND @doForeignKeyFlag = 1)
                    OR (constraintType = 'CHECK_CONSTRAINT' AND @doCheckFlag = 1))
             AND  schemaName LIKE @table_Schema
             AND  tableName LIKE @table_Name;

      OPEN @statements;

      DECLARE @statement varchar(1000), @schemaName sysname, 
              @tableName sysname, @constraintName sysname, 
              @constraintType sysname,@disabledFlag bit, @trustedFlag bit;

      WHILE 1=1
         BEGIN
              FETCH FROM @statements INTO @schemaName, @tableName, @constraintName,                 
                                          @constraintType, @disabledFlag, @trustedFlag;
               IF @@FETCH_STATUS <> 0
                    BREAK;

               BEGIN TRY -- will output an error if it occurs but will keep on going 
                        --so other constraints will be adjusted

                 IF @constraintType = 'CHECK_CONSTRAINT'

                            SELECT @statement = 'ALTER TABLE ' + @schemaName + '.' 
                                            + @tableName + ' WITH CHECK CHECK CONSTRAINT ' 
                                            + @constraintName;
                  ELSE IF @constraintType = 'FOREIGN_KEY_CONSTRAINT'
                            SELECT @statement = 'ALTER TABLE ' + @schemaName + '.' 
                                            + @tableName + ' WITH CHECK CHECK CONSTRAINT ' 
                                            + @constraintName;
                  EXEC (@statement);                                 
              END TRY
              BEGIN CATCH --output statement that was executed along with the error number
                  select 'Error occurred: ' + cast(error_number() as varchar(10))+ ':' +  
                          error_message() + char(13) + char(10) +  'Statement executed: ' +  
                          @statement;
              END CATCH
        END

   END
GO




CREATE TABLE Utility.ErrorLog(
        ErrorLogId int NOT NULL IDENTITY CONSTRAINT PKErrorLog PRIMARY KEY,
		Number int NOT NULL,
        Location sysname NOT NULL,
        Message varchar(4000) NOT NULL,
        LogTime datetime2(3) NULL
              CONSTRAINT DFLTErrorLog_error_date  DEFAULT (SYSDATETIME()),
        ServerPrincipal sysname NOT NULL
              --use original_login to capture the user name of the actual user
              --not a user they have impersonated
              CONSTRAINT DFLTErrorLog_error_user_name DEFAULT (ORIGINAL_LOGIN())
);
GO


CREATE PROCEDURE Utility.ErrorLog$Insert
(
        @ERROR_NUMBER int,
        @ERROR_LOCATION sysname,
        @ERROR_MESSAGE varchar(4000)
) AS
-- ----------------------------------------------------------------
-- Writes a row to the error log. If an error occurs in the call (such as a NULL value)
-- It writes a row to the error table. If that call fails an error will be returned
--
-- 2012 Louis Davidson – drsql@hotmail.com – drsql.org 
-- ----------------------------------------------------------------

 BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
           INSERT INTO Utility.ErrorLog(Number, Location,Message)
           SELECT @ERROR_NUMBER,COALESCE(@ERROR_LOCATION,'No Object'),@ERROR_MESSAGE;
        END TRY
        BEGIN CATCH
           INSERT INTO Utility.ErrorLog(Number, Location, Message)
           VALUES (-100, 'Utility.ErrorLog$insert',
                        'An invalid call was made to the error log procedure ' +  
                                     ERROR_MESSAGE());
        END CATCH
END;
GO


--test the error block we will use
BEGIN TRY
    THROW 50000,'Test error',16;
END TRY
BEGIN CATCH
    IF @@trancount > 0
        ROLLBACK TRANSACTION;

    --[Error logging section]
	DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
	        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
	EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

    THROW; --will halt the batch or be caught by the caller's catch block

END CATCH
GO


SELECT *
FROM  Utility.ErrorLog;
GO