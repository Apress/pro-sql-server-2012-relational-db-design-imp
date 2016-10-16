USE [master]
GO
CREATE LOGIN [DENALI-PC\AlienDrsql] FROM WINDOWS WITH DEFAULT_DATABASE=master, DEFAULT_LANGUAGE=us_english
GO
CREATE LOGIN [Fred] WITH PASSWORD=N'password' MUST_CHANGE, DEFAULT_DATABASE=[tempdb], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=ON, CHECK_POLICY=ON;
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [DENALI-PC\AlienDrsql];
GO

GRANT VIEW SERVER STATE to [Fred];
GO


CREATE SERVER ROLE SupportViewServer;
GO


GRANT  VIEW SERVER STATE to SupportViewServer;
GRANT  VIEW ANY DATABASE to SupportViewServer;
GO

ALTER SERVER ROLE SupportViewServer ADD MEMBER Fred;
Go
CREATE DATABASE ClassicSecurityExample;
GO

CREATE LOGIN Barney WITH PASSWORD=N'password', DEFAULT_DATABASE=[tempdb], 
             DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO


USE ClassicSecurityExample;
GO
GRANT CONNECT to guest;
GO


REVOKE Connect From Guest
GO

CREATE USER BarneyUser FROM LOGIN Barney;
GO
GRANT CONNECT to BarneyUser;
GO

--connecting as Barney in a different window
SELECT SUSER_SNAME() as server_principal_name, USER_NAME() as database_principal_name
Go

--================================
--ContainedDB Example


EXEC sp_configure 'show advanced options', 0;
GO
RECONFIGURE WITH OVERRIDE;
GO
EXECUTE sp_configure 'contained database authentication', 1;
GO
RECONFIGURE WITH OVERRIDE;
Go


USE [master]
GO
CREATE DATABASE ContainedDBSecurityExample;
GO
USE ContainedDBSecurityExample;
GO
ALTER DATABASE ContainedDBSecurityExample SET CONTAINMENT = PARTIAL;
GO


CREATE USER WilmaContainedUser WITH PASSWORD = 'p@ssword1';

CREATE LOGIN Pebbles WITH PASSWORD = 'BamBam01$';
GO
CREATE USER PebblesUnContainedUser FROM LOGIN Pebbles
GO

ALTER DATABASE ContainedDbSecurityExample  SET CONTAINMENT = none;
GO

SELECT name
FROM   sys.database_principals
WHERE  authentication_type_desc = 'DATABASE';
GO

--==================================
-- Impersonation

USE master;
GO
CREATE LOGIN system_admin WITH PASSWORD = 'tooHardToEnterAndNoOneKnowsIt',CHECK_POLICY=OFF;
EXEC sp_addsrvrolemember 'system_admin','sysadmin';

GO

CREATE LOGIN louis with PASSWORD = 'reasonable', DEFAULT_DATABASE=tempdb;

--Must execute in Master Database
GRANT IMPERSONATE ON LOGIN::system_admin TO louis;

GO
--in a different connection logged in as Louis
/*
USE ClassicSecurityExample
GO
EXECUTE AS LOGIN = 'system_admin'
GO

USE    ClassicSecurityExample
GO
SELECT user as [user], system_user as [system_user],
       original_login() as [original_login]
GO
REVERT --go back to previous security context
GO
USE tempdb

REVERT
SELECT user as [user], system_user as [system_user],
       original_login() as [original_login]
*/

--================================================
GO
USE Master
GO
SELECT  class_desc as permission_type, object_schema_name(major_id) + '.' + object_name(major_id) as object_name, 
		permission_name, state_desc, user_name(grantee_principal_id) as Grantee
FROM   sys.database_permissions
GO



USE ClassicSecurityExample;
GO
--start with a new schema for this test and create a table for our demonstrations
CREATE SCHEMA TestPerms;
GO

CREATE TABLE TestPerms.TableExample
(
    TableExampleId int identity(1,1)
                   CONSTRAINT PKTableExample PRIMARY KEY,
    Value   varchar(10)
);
GO

CREATE USER Tony WITHOUT LOGIN;
GO

EXECUTE AS USER = 'Tony';

INSERT INTO TestPerms.TableExample(Value)
VALUES ('a row');
GO

REVERT; --return to admin user context
GRANT INSERT on TestPerms.TableExample to Tony;
GO



EXECUTE AS USER = 'Tony';

INSERT INTO TestPerms.TableExample(Value)
VALUES ('a row');
GO

SELECT TableExampleId, value
FROM   TestPerms.TableExample;
GO

REVERT
GRANT SELECT on TestPerms.TableExample to Tony

EXECUTE AS USER = 'Tony';

SELECT TableExampleId, value
FROM   TestPerms.TableExample;

REVERT;
Go
--==============================================

CREATE USER Employee WITHOUT LOGIN;
CREATE USER Manager WITHOUT LOGIN;

GO

CREATE SCHEMA Products;
GO
CREATE TABLE Products.Product
(
    ProductId   int identity CONSTRAINT PKProduct PRIMARY KEY,
    ProductCode varchar(10) CONSTRAINT AKProduct_ProductCode UNIQUE,
    Description varchar(20),
    UnitPrice   decimal(10,4),
    ActualCost  decimal(10,4)
);
INSERT INTO Products.Product(ProductCode, Description, UnitPrice, ActualCost)
VALUES ('widget12','widget number 12',10.50,8.50),
       ('snurf98','Snurfulator',99.99,2.50);

GO

GRANT SELECT on Products.Product to employee,manager;
DENY SELECT on Products.Product (ActualCost) to employee;

GO

EXECUTE AS USER = 'manager';
SELECT  *
FROM    Products.Product;
GO

REVERT;--revert back to SA level user or you will get an error that the
       --user cannot do this operation because the manager user doesn't
       --have rights to impersonate the employee
GO
EXECUTE AS USER = 'employee';
GO
SELECT *
FROM   Products.Product;
GO


SELECT ProductId, ProductCode, Description, UnitPrice
FROM   Products.Product;

REVERT;
--===============================================


CREATE USER Frank WITHOUT LOGIN;
CREATE USER Julie WITHOUT LOGIN;
CREATE USER Rie WITHOUT LOGIN;
GO

CREATE ROLE HRWorkers;

ALTER ROLE HRWorkers ADD MEMBER Julie;
ALTER ROLE HRWorkers ADD MEMBER Rie;
GO


CREATE SCHEMA Payroll;
GO
CREATE TABLE Payroll.EmployeeSalary
(
    EmployeeId  int,
    SalaryAmount decimal(12,2)
);
GRANT SELECT ON Payroll.EmployeeSalary to HRWorkers;
GO


EXECUTE AS USER = 'Frank';

SELECT *
FROM   Payroll.EmployeeSalary;

GO

REVERT;
EXECUTE AS USER = 'Julie';

SELECT *
FROM   Payroll.EmployeeSalary;
GO

REVERT;
DENY SELECT ON payroll.employeeSalary TO Rie;
GO


EXECUTE AS USER = 'Rie';
SELECT *
FROM   payroll.employeeSalary;
GO

REVERT ;
EXECUTE AS USER = 'Julie';

--note, this query only returns rows for tables where the user has SOME rights
SELECT  TABLE_SCHEMA + '.' + TABLE_NAME as tableName,
        has_perms_by_name(TABLE_SCHEMA + '.' + TABLE_NAME, 'OBJECT', 'SELECT')
                                                                 as allowSelect,
        has_perms_by_name(TABLE_SCHEMA + '.' + TABLE_NAME, 'OBJECT', 'INSERT')
                                                                 as allowInsert
FROM    INFORMATION_SCHEMA.TABLES;
GO

REVERT;
GO
--============================================

CREATE TABLE TestPerms.BobCan
(
    BobCanId int identity(1,1) CONSTRAINT PKBobCan PRIMARY KEY,
    Value varchar(10)
);
CREATE TABLE TestPerms.AppCan
(
    AppCanId int identity(1,1) CONSTRAINT PKAppCan PRIMARY KEY,
    Value varchar(10)
);

GO

CREATE USER Bob WITHOUT LOGIN;
GO
GRANT SELECT on TestPerms.BobCan to Bob;
GO

GO

REVERT;
GO
EXECUTE sp_setapprole 'AppCan_application', '39292LjAsll2$3';
GO
SELECT * FROM TestPerms.BobCan;
GO
SELECT * from TestPerms.AppCan;
GO

SELECT user as userName, system_user as login;
GO


EXECUTE AS USER = 'Bob';
GO

SELECT * FROM TestPerms.BobCan;
GO
SELECT * FROM TestPerms.AppCan;
GO

REVERT;
GO
EXECUTE sp_setapprole 'AppCan_application', '39292ljasll23'
GO
SELECT * FROM TestPerms.BobCan
GO
SELECT * from TestPerms.AppCan
GO
SELECT user as userName, system_user as login
GO

--Note that this must be executed as a single batch because of the variable
--for the cookie
DECLARE @cookie varbinary(8000);
EXECUTE sp_setapprole 'AppCan_application', '39292ljasll23'
              , @fCreateCookie = true, @cookie = @cookie OUTPUT;

SELECT @cookie as cookie
SELECT USER as beforeUnsetApprole

EXEC sp_unsetapprole @cookie

SELECT USER as afterUnsetApprole

REVERT --done with this user
GO
--====================================

USE AdventureWorks2012;
GO
SELECT  type_desc, count(*)
FROM    sys.objects
WHERE   schema_name(schema_id) = 'HumanResources'
  AND   type_desc in ('SQL_STORED_PROCEDURE','CLR_STORED_PROCEDURE',
                      'SQL_SCALAR_FUNCTION','CLR_SCALAR_FUNCTION',
                      'CLR_TABLE_VALUED_FUNCTION','SYNONYM',
                      'SQL_INLINE_TABLE_VALUED_FUNCTION',
                      'SQL_TABLE_VALUED_FUNCTION','USER_TABLE','VIEW')
GROUP BY type_desc;
GO

USE ClassicSecurityExample;
GO

CREATE USER Tom WITHOUT LOGIN;
GRANT SELECT ON SCHEMA::TestPerms TO Tom;
GO

EXECUTE AS USER = 'Tom';
GO
SELECT * FROM TestPerms.AppCan;
GO
REVERT;
GO

CREATE TABLE TestPerms.SchemaGrant
(
    SchemaGrantId int primary key
);
GO
EXECUTE AS USER = 'Tom';
GO
SELECT * FROM TestPerms.schemaGrant;
GO
REVERT;
GO


--===========================================================


CREATE USER procUser WITHOUT LOGIN;
GO

CREATE SCHEMA procTest;
GO
CREATE TABLE procTest.misc
(
    Value varchar(20),
    Value2 varchar(20)
);
GO
INSERT INTO procTest.misc
VALUES ('somevalue','secret'),
       ('anothervalue','secret');

GO


CREATE PROCEDURE procTest.misc$select
AS
    SELECT Value
    FROM   procTest.misc;
GO
GRANT EXECUTE on procTest.misc$select to procUser;
GO


EXECUTE AS USER = 'procUser';
GO
SELECT Value, Value2
FROM   procTest.misc;
GO

EXECUTE procTest.misc$select;
GO

SELECT schema_name(schema_id) +'.' + name AS procedure_name
FROM   sys.procedures;


REVERT;

--==============================================

--this will be the owner of the primary schema
CREATE USER schemaOwner WITHOUT LOGIN;
GRANT CREATE SCHEMA TO schemaOwner;
GRANT CREATE TABLE TO schemaOwner;

--this will be the procedure creator
CREATE USER procedureOwner WITHOUT LOGIN;
GRANT CREATE SCHEMA TO procedureOwner;
GRANT CREATE PROCEDURE TO procedureOwner;
GRANT CREATE TABLE TO procedureOwner;
GO

--this will be the average user who needs to access data
CREATE USER aveSchlub WITHOUT LOGIN;
GO

EXECUTE AS USER = 'schemaOwner';
GO
CREATE SCHEMA schemaOwnersSchema;
GO
CREATE TABLE schemaOwnersSchema.Person
(
    PersonId    int constraint PKtestAccess_Person primary key,
    FirstName   varchar(20),
    LastName    varchar(20)
);
GO
INSERT INTO schemaOwnersSchema.Person
VALUES (1, 'Phil','Mutayblin'),
       (2, 'Del','Eets');

GO

GRANT SELECT on schemaOwnersSchema.Person TO procedureOwner;
GO

REVERT;--we can step back on the stack of principals,
        --but we can't change directly
        --to procedureOwner. Here I step back to the db_owner user you have
        --used throughout the chapter
GO
EXECUTE AS USER = 'procedureOwner';
GO

CREATE SCHEMA procedureOwnerSchema;
GO
CREATE TABLE procedureOwnerSchema.OtherPerson
(
    personId    int constraint PKtestAccess_person primary key,
    FirstName   varchar(20),
    LastName    varchar(20)
);
GO
INSERT INTO procedureOwnerSchema.OtherPerson
VALUES (1, 'DB','Smith');
INSERT INTO procedureOwnerSchema.OtherPerson
VALUES (2, 'Dee','Leater');
GO

REVERT;

SELECT tables.name as [table], schemas.name as [schema],
       database_principals.name as [owner]
FROM   sys.tables
         JOIN sys.schemas
            ON tables.schema_id = schemas.schema_id
         JOIN sys.database_principals
            ON database_principals.principal_id = schemas.principal_id
WHERE  tables.name in ('Person','OtherPerson');

GO

EXECUTE AS USER = 'procedureOwner';
GO

CREATE PROCEDURE  procedureOwnerSchema.person$asCaller
WITH EXECUTE AS CALLER --this is the default
AS
BEGIN
   SELECT  personId, FirstName, LastName
   FROM    procedureOwnerSchema.OtherPerson; --<-- ownership same as proc

   SELECT  personId, FirstName, LastName
  FROM    schemaOwnersSchema.person;  --<-- breaks ownership chain
END;
GO

CREATE PROCEDURE procedureOwnerSchema.person$asSelf
WITH EXECUTE AS SELF --now this runs in context of procedureOwner,
                     --since it created it
AS
BEGIN
   SELECT  personId, FirstName, LastName
   FROM    procedureOwnerSchema.OtherPerson; --<-- ownership same as proc

   SELECT  personId, FirstName, LastName
   FROM    schemaOwnersSchema.person;  --<-- breaks ownership chain
END;
GO


GRANT EXECUTE ON procedureOwnerSchema.person$asCaller TO aveSchlub;
GRANT EXECUTE ON procedureOwnerSchema.person$asSelf TO aveSchlub;
GO

REVERT; EXECUTE AS USER = 'aveSchlub';
GO

--this proc is in context of the caller, in this case, aveSchlub
EXECUTE procedureOwnerSchema.person$asCaller;
GO

--procedureOwner, so it works
EXECUTE procedureOwnerSchema.person$asSelf;

GO
--===================================
REVERT;
GO
CREATE PROCEDURE dbo.testDboRights
AS
 BEGIN
    CREATE TABLE dbo.test
    (
        testId int
    );
 END;
GO



CREATE USER leroy WITHOUT LOGIN;
GRANT EXECUTE on dbo.testDboRights TO Leroy;

GO
EXECUTE AS USER = 'leroy';
EXECUTE dbo.testDboRights;
GO


REVERT;
GO
ALTER PROCEDURE dbo.testDboRights
WITH EXECUTE AS 'dbo'
AS
 BEGIN
    CREATE TABLE dbo.test
    (
        testId int
    );
 END;
GO



REVERT;
GO
SELECT *
FROM   Products.Product;
GO


CREATE VIEW Products.allProducts
AS
SELECT ProductId,ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product;
GO


CREATE VIEW Products.WarehouseProducts
AS
SELECT ProductId,ProductCode, Description
FROM   Products.Product;
GO


CREATE FUNCTION Products.ProductsLessThanPrice
(
    @UnitPrice  decimal(10,4)
)
RETURNS table
AS
     RETURN ( SELECT ProductId, ProductCode, Description, UnitPrice
              FROM   Products.Product
              WHERE  UnitPrice <= @UnitPrice);
GO


SELECT * FROM Products.ProductsLessThanPrice(20);
GO

CREATE FUNCTION Products.ProductsLessThanPrice_GroupEnforced
(
    @UnitPrice  decimal(10,4)
)
RETURNS @output table (ProductId int,
                       ProductCode varchar(10),
                       Description varchar(20),
                       UnitPrice decimal(10,4))
AS
 BEGIN
    --cannot raise an error, so you have to implement your own
    --signal, or perhaps simply return no data.
    IF @UnitPrice > 100 and (
                             IS_MEMBER('HighPriceProductViewer') = 0
                             or IS_MEMBER('HighPriceProductViewer') is null)
        INSERT @output
        SELECT -1,'ERROR','',-1;
    ELSE
        INSERT @output
        SELECT ProductId, ProductCode, Description, UnitPrice
        FROM   Products.Product
        WHERE  UnitPrice <= @UnitPrice;
    RETURN;
 END;

GO

CREATE ROLE HighPriceProductViewer;
CREATE ROLE ProductViewer;
GO
CREATE USER HighGuy WITHOUT LOGIN;
CREATE USER LowGuy WITHOUT LOGIN;
GO
ALTER ROLE HighPriceProductViewer ADD MEMBER HighGuy;
ALTER ROLE ProductViewer ADD MEMBER HighGuy;
ALTER ROLE ProductViewer ADD MEMBER LowGuy;
GO


GRANT SELECT ON Products.ProductsLessThanPrice_GroupEnforced TO ProductViewer;
GO


EXECUTE AS USER = 'HighGuy';

SELECT * 
FROM Products.ProductsLessThanPrice_GroupEnforced(10000);

REVERT;
GO


EXECUTE AS USER = 'LowGuy';

SELECT * 
FROM Products.ProductsLessThanPrice_GroupEnforced(10000);

REVERT;

GO
--==========================================================

ALTER TABLE Products.Product
   ADD ProductType varchar(20) NULL;
GO
UPDATE Products.Product
SET    ProductType = 'widget'
WHERE  ProductCode = 'widget12';
GO
UPDATE Products.Product
SET    ProductType = 'snurf'
WHERE  ProductCode = 'snurf98';
GO



SELECT *
FROM   Products.Product;
GO


CREATE VIEW Products.WidgetProducts
AS
SELECT ProductId, ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product
WHERE  ProductType = 'widget'
WITH   CHECK OPTION; --This prevents the user from entering data that would not
                     --match the view's criteria
GO


SELECT *
FROM   Products.WidgetProducts;

GO
--=================
CREATE VIEW Products.ProductsSelective
AS
SELECT ProductId, ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product
WHERE  ProductType <> 'snurf'
   or  (is_member('snurfViewer') = 1)
   or  (is_member('db_owner') = 1) --can't add db_owner to a role
WITH CHECK OPTION;
GO


GRANT SELECT ON Products.ProductsSelective TO public;
GO

CREATE USER chrissy WITHOUT LOGIN;
CREATE ROLE snurfViewer;
GO

EXECUTE AS USER = 'chrissy';
SELECT * from Products.ProductsSelective;
REVERT;

GO
ALTER ROLE snurfViewer ADD MEMBER chrissy;
GO

EXECUTE AS USER = 'chrissy';
SELECT * 
FROM Products.ProductsSelective;

REVERT;

GO


CREATE TABLE Products.ProductSecurity
(
    ProductsSecurityId int identity(1,1)
                CONSTRAINT PKProducts_ProductsSecurity PRIMARY KEY,
    ProductType varchar(20), --at this point you probably will create a
                             --ProductType domain table, but this keeps the
                             --example a bit simpler
    DatabaseRole    sysname,
                CONSTRAINT AKProducts_ProductsSecurity_typeRoleMapping
                            UNIQUE (ProductType, DatabaseRole)
);

GO


INSERT INTO Products.ProductSecurity(ProductType, DatabaseRole)
VALUES ('widget','public');
GO


ALTER VIEW Products.ProductsSelective
AS
SELECT Product.ProductId, Product.ProductCode, Product.Description,
       Product.UnitPrice, Product.ActualCost, Product.ProductType
FROM   Products.Product as Product
         JOIN Products.ProductSecurity as ProductSecurity
            on  (Product.ProductType = ProductSecurity.ProductType
                and is_member(ProductSecurity.DatabaseRole) = 1)
                or is_member('db_owner') = 1; --don't leave out the dbo!
GO


EXECUTE AS USER = 'chrissy';
SELECT *
FROM   Products.ProductsSelective;
REVERT;

GO
INSERT INTO Products.ProductSecurity(ProductType, databaseRole)
VALUES ('snurf','snurfViewer');
GO
EXECUTE AS USER = 'chrissy';
SELECT * FROM Products.ProductSecurity;
REVERT;

GO

--============================================

CREATE DATABASE externalDb;
GO
USE externalDb;
GO
                                   --smurf theme song :)
CREATE LOGIN smurf WITH PASSWORD = 'La la, la la la la, la, la la la la';
CREATE USER smurf FROM LOGIN smurf;
CREATE TABLE dbo.table1 ( value int );

GO

CREATE DATABASE localDb;
GO
USE localDb;
GO
CREATE USER smurf FROM LOGIN smurf;
GO

ALTER AUTHORIZATION ON DATABASE::externalDb To sa;
ALTER AUTHORIZATION ON DATABASE::localDb To sa;
GO

SELECT name,suser_sname(owner_sid) as owner
FROM   sys.databases
WHERE  name in ('externalDb','LocalDb')

GO

CREATE PROCEDURE dbo.externalDb$testCrossDatabase
AS
SELECT Value
FROM   externalDb.dbo.table1;
GO
GRANT execute ON dbo.externalDb$testCrossDatabase TO smurf;
GO



EXECUTE dbo.externalDb$testCrossDatabase;
GO

EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase;
GO
REVERT;
GO

ALTER DATABASE localDb
   SET DB_CHAINING ON
ALTER DATABASE localDb
   SET TRUSTWORTHY ON

ALTER DATABASE externalDb
   SET DB_CHAINING ON
GO


SELECT name, is_trustworthy_on, is_db_chaining_on
FROM   sys.databases
WHERE  name in ('externalDb','LocalDb');


GO
EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase
GO
REVERT
GO


ALTER DATABASE localDB  SET CONTAINMENT = PARTIAL;
GO


EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase
GO
REVERT
GO

CREATE USER Gargy WITH PASSWORD = 'Nasty1$';
GO 
GRANT EXECUTE ON dbo.externalDb$testCrossDatabase to Gargy;
GO



EXECUTE AS USER = 'Gargy'
go
use externalDb
GO



EXECUTE dbo.externalDb$testCrossDatabase;
GO
REVERT;
GO
SELECT  object_name(major_id) as object_name,statement_line_number, 
        statement_type, feature_name, feature_type_name
FROM    sys.dm_db_uncontained_entities AS e
WHERE   class_desc = 'OBJECT_OR_COLUMN';
GO
SELECT  USER_NAME(major_id) as USER_NAME,*
FROM    sys.dm_db_uncontained_entities AS e
WHERE   class_desc = 'DATABASE_PRINCIPAL'
  and   USER_NAME(major_id) <> 'dbo';
GO



DROP USER Gargy
GO
USE Master
GO
ALTER DATABASE localDB  SET CONTAINMENT = NONE
GO
USE LocalDb
GO
--======================================

ALTER DATABASE localDb
   SET DB_CHAINING OFF;
ALTER DATABASE localDb
   SET TRUSTWORTHY ON;

ALTER DATABASE externalDb
   SET DB_CHAINING OFF;
GO

CREATE PROCEDURE dbo.externalDb$testCrossDatabase_Impersonation
WITH EXECUTE AS SELF --as procedure creator, who is the same as the db owner
AS
SELECT Value
FROM   externalDb.dbo.table1;
GO
GRANT execute on dbo.externalDb$testCrossDatabase_impersonation to smurf;
GO

EXECUTE AS USER = 'smurf';
GO
EXECUTE dbo.externalDb$testCrossDatabase_impersonation;
GO
REVERT;
GO

ALTER DATABASE localDb
   SET TRUSTWORTHY OFF;
GO
EXECUTE dbo.externalDb$testCrossDatabase_impersonation;
GO

--============

ALTER DATABASE localDb  SET TRUSTWORTHY ON;
GO
ALTER DATABASE localDB  SET CONTAINMENT = PARTIAL;
GO
CREATE USER Gargy WITH PASSWORD = 'Nasty1$';
GO 
GRANT EXECUTE ON externalDb$testCrossDatabase_Impersonation to Gargy;

GO


EXECUTE AS USER = 'Gargy';
GO
EXECUTE dbo.externalDb$testCrossDatabase_Impersonation;
GO
REVERT;

GO

DROP USER Gargy;
GO
USE Master;
GO
ALTER DATABASE localDB  SET CONTAINMENT = NONE;
GO
USE LocalDb;

GO
--=============================

REVERT;
GO
USE localDb;
GO
ALTER DATABASE localDb
   SET TRUSTWORTHY OFF;

GO


SELECT name,
       suser_sname(owner_sid) as owner,
       is_trustworthy_on, is_db_chaining_on
FROM   sys.databases where name in ('localdb','externaldb');
GO

--====================================

CREATE PROCEDURE dbo.externalDb$testCrossDatabase_Certificate
AS
SELECT Value
FROM   externalDb.dbo.table1;
GO
GRANT EXECUTE on dbo.externalDb$testCrossDatabase_Certificate to smurf;
GO



CREATE CERTIFICATE procedureExecution ENCRYPTION BY PASSWORD = 'jsaflajOIo9jcCMd;SdpSljc'
 WITH SUBJECT =
         'Used to sign procedure:externalDb$testCrossDatabase_Certificate';
GO


ADD SIGNATURE TO dbo.externalDb$testCrossDatabase_Certificate
     BY CERTIFICATE procedureExecution WITH PASSWORD = 'jsaflajOIo9jcCMd;SdpSljc';
GO

BACKUP CERTIFICATE procedureExecution TO FILE = 'c:\temp\procedureExecution.cer';
GO


USE externalDb;
GO
CREATE CERTIFICATE procedureExecution FROM FILE = 'c:\temp\procedureExecution.cer';
GO

CREATE USER procCertificate FOR CERTIFICATE procedureExecution;
GO
GRANT SELECT on dbo.table1 TO procCertificate;
GO

USE localDb;
GO
EXECUTE AS LOGIN = 'smurf';
EXECUTE dbo.externalDb$testCrossDatabase_Certificate;
GO

REVERT
GO


REVERT;
GO
USE MASTER;
GO
DROP DATABASE externalDb;
DROP DATABASE localDb;
GO
USE ClassicSecurityExample;



--========================================

SELECT encryptByPassPhrase('hi', 'Secure data');

SELECT decryptByPassPhrase('hi',
   0x010000005CF02533E8347157CBDE469F13043746E55406FE854647C8A9BBB4D3CC4CC533)
GO

SELECT CAST(decryptByPassPhrase('hi',
     0x010000004D2B87C6725612388F8BA4DA082495E8C836FF76F32BCB642B36476594B4F014)
                                              AS VARCHAR(30));
GO

--===========================================


USE master;
GO
CREATE SERVER AUDIT ProSQLServerDatabaseDesign_Audit
TO FILE                      --choose your own directory, I expect most people
(     FILEPATH = N'c:\temp\' --have a temp directory on their system drive
      ,MAXSIZE = 15 MB
      ,MAX_ROLLOVER_FILES = 0 --unlimited
)
WITH
(
     ON_FAILURE = SHUTDOWN --if the file cannot be written to,
                           --shut down the server
);

GO

CREATE SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF); --disabled. I will enable it later
GO


ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP);

GO

USE ClassicSecurityExample;
GO
CREATE DATABASE AUDIT SPECIFICATION
                   ProSQLServerDatabaseDesign_Database_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF);

GO

ALTER DATABASE AUDIT SPECIFICATION
    ProSQLServerDatabaseDesign_Database_Audit
    ADD (SELECT ON Products.Product BY employee, manager),
    ADD (SELECT ON Products.AllProducts BY employee, manager);

GO



USE master;
GO
ALTER SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = ON);
ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    WITH (STATE = ON);
GO
USE ClassicSecurityExample;
GO
ALTER DATABASE AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Database_Audit
    WITH (STATE = ON);
GO


CREATE LOGIN MrSmith WITH PASSWORD = 'Not a good password';
GO
EXECUTE AS USER = 'manager';
GO
SELECT *
FROM   Products.Product;
GO
SELECT  *
FROM    Products.AllProducts; --Permissions will fail
GO
REVERT
GO
EXECUTE AS USER = 'employee';
GO
SELECT  *
FROM    Products.AllProducts; --Permissions will fail
GO
REVERT;
GO



SELECT event_time, succeeded,
       database_principal_name, statement
FROM sys.fn_get_audit_file ('c:\temp\*',default,default);


GO


SELECT  sas.name as audit_specification_name,
        audit_action_name
FROM    sys.server_audits as sa
          JOIN sys.server_audit_specifications as sas
             ON sa.audit_guid = sas.audit_guid
          JOIN sys.server_audit_specification_details as sasd
             ON sas.server_specification_id = sasd.server_specification_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit';




SELECT --sas.name  as audit_specification_name,
       audit_action_name,dp.name as [principal],
       SCHEMA_NAME(o.schema_id) + '.' + o.name as object
FROM   sys.server_audits as sa
         join sys.database_audit_specifications as sas
             on sa.audit_guid = sas.audit_guid
         join sys.database_audit_specification_details as sasd
             on sas.database_specification_id = sasd.database_specification_id
         join sys.database_principals as dp
             on dp.principal_id = sasd.audited_principal_id
         join sys.objects as o
             on o.object_id = sasd.major_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit'
  and  sasd.minor_id = 0; --need another query for column level audits

--====================================

USE ClassicSecurityExample; 
GO
CREATE SCHEMA Sales;
GO
CREATE SCHEMA Inventory;
GO
CREATE TABLE Sales.invoice
(
    InvoiceId   int not null identity(1,1) CONSTRAINT PKInvoice PRIMARY KEY,
    InvoiceNumber char(10) not null
                      CONSTRAINT AKInvoice_InvoiceNumber UNIQUE,
    CustomerName varchar(60) not null , --should be normalized in real database
    InvoiceDate smalldatetime not null
);
CREATE TABLE Inventory.Product
(
    ProductId int identity(1,1) CONSTRAINT PKProduct PRIMARY KEY,
    name varchar(30) not null CONSTRAINT AKProduct_name UNIQUE,
    Description varchar(60) not null ,
    Cost numeric(12,4) not null
);
CREATE TABLE Sales.InvoiceLineItem
(
    InvoiceLineItemId int identity(1,1)
                      CONSTRAINT PKInvoiceLineItem PRIMARY KEY,
    InvoiceId int not null,
    ProductId int not null,
    Quantity numeric(6,2) not null,
    Cost numeric(12,4) not null,
    discount numeric(3,2) not null,
    discountExplanation varchar(200) not null,
    CONSTRAINT AKInvoiceLineItem_InvoiceAndProduct
             UNIQUE (InvoiceId, ProductId),
    CONSTRAINT FKSales_Invoice$listsSoldProductsIn$Sales_InvoiceLineItem
             FOREIGN KEY (InvoiceId) REFERENCES Sales.Invoice(InvoiceId),
    CONSTRAINT FKSales_Product$isSoldVia$Sales_InvoiceLineItem
             FOREIGN KEY (InvoiceId) REFERENCES Sales.Invoice(InvoiceId)
    --more constraints should be in place for full implementation
);




GO

CREATE TRIGGER Sales.InvoiceLineItem$insertAndUpdateAuditTrail
ON Sales.InvoiceLineItem
AFTER INSERT,UPDATE AS
BEGIN
   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --           @rowsAffected int = (SELECT COUNT(*) FROM deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   BEGIN TRY
      --[validation blocks]
      --[modification blocks]
      IF UPDATE(Cost)
         INSERT INTO Sales.InvoiceLineItemDiscountAudit (InvoiceId,
                         InvoiceLineItemId, AuditTime, SetByUserId, Quantity,
                         Cost, Discount, DiscountExplanation)
         SELECT inserted.InvoiceId, inserted.InvoiceLineItemId,
                current_timestamp, suser_sname(), inserted.Quantity,
                inserted.Cost, inserted.Discount,
                inserted.DiscountExplanation

         FROM   inserted
                   join Inventory.Product as Product
                      on inserted.ProductId = Product.ProductId
         --if the Discount is more than 0, or the cost supplied is less than the
         --current value
         WHERE   inserted.Discount > 0
            or   inserted.Cost < Product.Cost;
                      -- if it was the same or greater, that is good!
                      -- this keeps us from logging if the cost didn't actually
                      -- change
   END TRY
   BEGIN CATCH
               IF @@trancount > 0
                     ROLLBACK TRANSACTION;

              THROW;

     END CATCH
END

GO

INSERT INTO Inventory.Product(name, Description,Cost)
VALUES ('Duck Picture','Picture on the wall in my hotelRoom',200.00),
       ('Cow Picture','Picture on the other wall in my hotelRoom',150.00);

GO

INSERT INTO Sales.Invoice(InvoiceNumber, CustomerName, InvoiceDate)
VALUES ('IE00000001','The Hotel Picture Company','2012-01-01');
GO


INSERT INTO Sales.InvoiceLineItem(InvoiceId, ProductId, Quantity,
                                  Cost, Discount, DiscountExplanation)
SELECT  (SELECT InvoiceId
         FROM   Sales.Invoice
         WHERE  InvoiceNumber = 'IE00000001'),
        (SELECT ProductId
         FROM   Inventory.Product
         WHERE  Name = 'Duck Picture'),  1,200,0,'';

GO

SELECT * FROM Sales.InvoiceLineItemDiscountAudit;
GO


INSERT INTO Sales.InvoiceLineItem(InvoiceId, ProductId, Quantity,
                                  Cost, Discount, DiscountExplanation)
SELECT  (SELECT InvoiceId
         FROM Sales.Invoice
         WHERE InvoiceNumber = 'IE00000001'),
        (SELECT ProductId
         FROM Inventory.Product
         WHERE name = 'Cow Picture'),
        1,150,.45,'Customer purchased two, so I gave 45% off';

GO

SELECT * FROM Sales.InvoiceLineItemDiscountAudit
GO

--==============================================

CREATE TRIGGER tr_server$allTableDDL_prevent --note, not a schema owned object
ON DATABASE
AFTER CREATE_TABLE, DROP_TABLE, ALTER_TABLE
AS
 BEGIN
   BEGIN TRY  --note the following line will not wrap
        RAISERROR ('The trigger: tr_server$allTableDDL_prevent must be disabled
                    before making any table modifications',16,1);
   END TRY
   --using the same old error handling
   BEGIN CATCH
              IF @@trancount > 0
                    ROLLBACK TRANSACTION;

              THROW;
     END CATCH
END;

GO

CREATE TABLE dbo.testDDLTrigger  --dbo for simplicity of example
(
    testDDLTriggerId int identity CONSTRAINT PKtest PRIMARY KEY
);

DROP TRIGGER tr_server$allTableDDL_prevent --note, not a schema owned object
ON DATABASE
GO

--=====================


--first create a table to log to
CREATE TABLE dbo.TableChangeLog
(
    TableChangeLogId int identity
        CONSTRAINT pkTableChangeLog PRIMARY KEY (TableChangeLogId),
    ChangeTime      datetime,
    UserName        sysname,
    Ddl             varchar(max)--so we can get as much of the batch as possible
);

GO

--not a schema bound object
CREATE TRIGGER tr_server$allTableDDL
ON DATABASE
AFTER CREATE_TABLE, DROP_TABLE, ALTER_TABLE
AS
 BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY

        --we get our data from the EVENT_INSTANCE XML stream
        INSERT INTO dbo.TableChangeLog (ChangeTime, userName, Ddl)
        SELECT getdate(), user,
              EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]',
             'nvarchar(max)');

   END TRY
   --using the same old error handling
   BEGIN CATCH
              IF @@trancount > 0
                     ROLLBACK TRANSACTION;
              THROW;

     END CATCH
END;

GO

CREATE TABLE dbo.testDdlTrigger
(
    testDdlTriggerId int
);
GO
DROP TABLE dbo.testDdlTrigger;

GO

SELECT * FROM dbo.TableChangeLog;