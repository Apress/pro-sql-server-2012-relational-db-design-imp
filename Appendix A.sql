DECLARE @DateValue datetime2(3) = '2012-05-21 15:45:01.456'
SELECT @DateValue as Unformatted,
       FORMAT(@DateValue,'yyyyMMdd') as IsoUnseperated, 
       FORMAT(@DateValue,'yyyy-MM-ddThh:mm:ss') as IsoDateTime, 
       FORMAT(@DateValue,'D','en-US' ) as USRegional,
       FORMAT(@DateValue,'D','en-GB' ) as GBRegional,
       FORMAT(@DateValue,'D','fr-fr' ) as FRRegional;
Go

DECLARE @value varchar(max);
SET @value = replicate('X',8000) + replicate('X',8000);
SELECT len(@value);
GO

DECLARE @value varchar(max);
SET @value = replicate(cast('X' as varchar(max)),16000);
SELECT len(@value);

GO
SELECT N'Unicode Value';
GO

DECLARE @value binary(10);
SET @value = CAST('helloworld' AS binary(10));
SELECT @value;
GO

select cast(0x68656C6C6F776F726C64 as varchar(10));
GO



SET NOCOUNT ON;
CREATE TABLE testRowversion
(
   value   varchar(20) NOT NULL,
   auto_rv   rowversion NOT NULL
);

INSERT INTO testRowversion (value) values ('Insert');

SELECT value, auto_rv FROM testRowversion
UPDATE testRowversion
SET value = 'First Update';

SELECT value, auto_rv from testRowversion
UPDATE testRowversion
SET value = 'Last Update';

SELECT value, auto_rv FROM testRowversion;
GO


DECLARE @guidVar uniqueidentifier;
SET @guidVar = NEWID();

SELECT @guidVar AS guidVar;
GO

CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL ROWGUIDCOL DEFAULT NEWID(),
   value varchar(10)
);

INSERT INTO guidPrimaryKey(value)
VALUES ('Test');

SELECT *
FROM guidPrimaryKey;
GO

DROP TABLE guidPrimaryKey
go
CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL
                    ROWGUIDCOL DEFAULT NEWSEQUENTIALID(),
   value varchar(10)
);
GO
INSERT INTO guidPrimaryKey(value)
VALUES('Test'),('Test1'),('Test2');
GO

SELECT *
FROM guidPrimaryKey;
GO


DECLARE @tableVar TABLE
(
   id int IDENTITY PRIMARY KEY,
   value varchar(100)
);
INSERT INTO @tableVar (value)
VALUES ('This is a cool test');

SELECT id, value
FROM @tableVar;
GO


CREATE FUNCTION table$testFunction
(
   @returnValue varchar(100)

)
RETURNS @tableVar table
(
     value varchar(100)
)
AS
BEGIN
   INSERT INTO @tableVar (value)
   VALUES (@returnValue);

   RETURN;
END;
GO

SELECT *
FROM dbo.table$testFunction('testValue');

GO



DECLARE @tableVar TABLE
(
   id int IDENTITY,
   value varchar(100)
);
BEGIN TRANSACTION
    INSERT INTO @tableVar (value)
    VALUES ('This will still be there');
ROLLBACK TRANSACTION;

SELECT id, value
FROM @tableVar;
GO



CREATE TYPE GenericIdList AS TABLE
(
    Id Int Primary Key
);


GO

DECLARE @ProductIdList GenericIdList

INSERT INTO @productIDList
VALUES (1),(2),(3),(4);

SELECT ProductID, Name, ProductNumber
FROM   AdventureWorks2012.Production.Product
         JOIN @productIDList as List
            on Product.ProductID = List.Id
GO

CREATE PROCEDURE product$list
(
    @productIdList GenericIdList READONLY
)
AS
SELECT ProductID, Name, ProductNumber
FROM   AdventureWorks2012.Production.Product
         JOIN @productIDList as List
            on Product.ProductID = List.Id;
GO

DECLARE @ProductIdList GenericIdList

INSERT INTO @productIDList
VALUES (1),(2),(3),(4)

EXEC product$list @ProductIdList
GO


DECLARE @varcharVariant sql_variant = '1234567890';

SELECT @varcharVariant AS varcharVariant,
   SQL_VARIANT_PROPERTY(@varcharVariant,'BaseType') as baseType,
   SQL_VARIANT_PROPERTY(@varcharVariant,'MaxLength') as maxLength,
   SQL_VARIANT_PROPERTY(@varcharVariant,'Collation') as collation;

GO

DECLARE @numericVariant sql_variant = 123456.789;

SELECT @numericVariant AS numericVariant,
   SQL_VARIANT_PROPERTY(@numericVariant,'BaseType') as baseType,
   SQL_VARIANT_PROPERTY(@numericVariant,'Precision') as precision,
   SQL_VARIANT_PROPERTY(@numericVariant,'Scale') as scale;
GO

