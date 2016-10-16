
BEGIN TRANSACTION one;
ROLLBACK TRANSACTION one;
GO


BEGIN TRANSACTION one;
BEGIN TRANSACTION two;
ROLLBACK TRANSACTION two;
GO
ROLLBACK TRANSACTION;
GO


SELECT  recovery_model_desc
FROM    sys.databases
WHERE   name = 'AdventureWorks2012 ';

GO


USE Master;
GO

ALTER DATABASE AdventureWorks2012
      SET RECOVERY FULL;
GO

EXEC sp_addumpdevice 'disk', 'TestAdventureWorks2012',
                              'C:\SQL\Backup\AdventureWorks2012.bak';
EXEC sp_addumpdevice 'disk', 'TestAdventureWorks2012Log',
                              'C:\SQL\Backup\AdventureWorks2012Log.bak';
GO

BACKUP DATABASE AdventureWorks2012 TO TestAdventureWorks2012 WITH FORMAT;
GO

USE AdventureWorks2012;
GO
SELECT COUNT(*)
FROM   Sales.SalesTaxRate;

BEGIN TRANSACTION Test WITH MARK 'Test';
DELETE Sales.SalesTaxRate;
COMMIT TRANSACTION;
GO

BACKUP LOG AdventureWorks2012 to TestAdventureWorks2012Log  WITH FORMAT;
GO


USE Master
GO
RESTORE DATABASE AdventureWorks2012 FROM TestAdventureWorks2012 
                                                WITH REPLACE, NORECOVERY;

RESTORE LOG AdventureWorks2012 FROM TestAdventureWorks2012Log
                                                WITH STOPBEFOREMARK = 'Test', RECOVERY;

GO
USE AdventureWorks2012;
GO
SELECT COUNT(*)
FROM   Sales.SalesTaxRate;

GO
--====================================================

SELECT @@TRANCOUNT AS zeroDeep;
BEGIN TRANSACTION
SELECT @@TRANCOUNT AS oneDeep;

GO


BEGIN TRANSACTION
SELECT @@TRANCOUNT AS twoDeep;
COMMIT TRANSACTION --commits very last transaction started with BEGIN TRANSACTION
SELECT @@TRANCOUNT AS oneDeep;
GO

COMMIT TRANSACTION
SELECT @@TRANCOUNT AS zeroDeep
GO

BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
SELECT @@trancount as InTran;

ROLLBACK TRANSACTION;
SELECT @@trancount as OutTran;

GO

SELECT @@trancount;
COMMIT TRANSACTION;


--=================================================
USE TempDb;
GO
CREATE SCHEMA arts;
GO
CREATE TABLE arts.performer
(
    performerId int NOT NULL IDENTITY,
    name varchar(100) NOT NULL
 );
GO
BEGIN TRANSACTION;
INSERT INTO arts.performer(name) VALUES ('Elvis Costello');

SAVE TRANSACTION savePoint;

INSERT INTO arts.performer(name) VALUES ('Air Supply');

--don't insert Air Supply, yuck! ...
ROLLBACK TRANSACTION savePoint;

COMMIT TRANSACTION;

SELECT *
FROM arts.performer ;
GO

--==================================

CREATE PROCEDURE tranTest
AS
BEGIN
  SELECT @@TRANCOUNT AS trancount;

  BEGIN TRANSACTION;
  ROLLBACK TRANSACTION;
END;

GO


EXECUTE tranTest;
GO


BEGIN TRANSACTION;

EXECUTE tranTest;
COMMIT TRANSACTION;

GO


ALTER PROCEDURE tranTest
AS
BEGIN
  --gives us a unique savepoint name, trim it to 125 characters if the
  --user named the procedure really really large, to allow for nestlevel
  DECLARE @savepoint nvarchar(128) = 
      cast(object_name(@@procid) AS nvarchar(125)) +
                         cast(@@nestlevel AS nvarchar(3));

  SELECT @@TRANCOUNT AS trancount;
  BEGIN TRANSACTION;
  SAVE TRANSACTION @savepoint;
    --do something here
  ROLLBACK TRANSACTION @savepoint;
  COMMIT TRANSACTION;
END;

GO

BEGIN TRANSACTION;

EXECUTE tranTest;
COMMIT TRANSACTION;
GO


ALTER PROCEDURE tranTest
AS
BEGIN
  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3));
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount;

  BEGIN TRY
    BEGIN TRANSACTION;
    SAVE TRANSACTION @savepoint;

    --do something here
    THROW 50000, 'Invalid Operation',16;

    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH 

   --if the tran is doomed, and the entryTrancount was 0,
   --we have to roll back    
    IF xact_state()= -1 and @entryTrancount = 0 
        rollback transaction;
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         ROLLBACK TRANSACTION @savepoint;
         COMMIT TRANSACTION;
       END

    DECLARE @ERRORmessage nvarchar(4000);
    SET @ERRORmessage = 'Error occurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + '''';
    THROW 50000, @ERRORmessage,16;
    RETURN -100
  END CATCH
END;

GO

CREATE SCHEMA menu;
GO
CREATE TABLE menu.foodItem
(
    foodItemId int not null IDENTITY(1,1)
        CONSTRAINT PKmenu_foodItem PRIMARY KEY,
    name varchar(30) not null
        CONSTRAINT AKmenu_foodItem_name UNIQUE,
    description varchar(60) not null,
        CONSTRAINT CHKmenu_foodItem_name CHECK (name <> ''),
        CONSTRAINT CHKmenu_foodItem_description CHECK (description <> '')
);

GO
CREATE PROCEDURE menu.foodItem$insert
(
    @name   varchar(30),
    @description varchar(60),
    @newFoodItemId int = null output --we will send back the new id here
)
AS
BEGIN
  SET NOCOUNT ON;

  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3));
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount;

  BEGIN TRY
    BEGIN TRANSACTION;
    SAVE TRANSACTION @savepoint;

    INSERT INTO menu.foodItem(name, description)
    VALUES (@name, @description);

    SET @newFoodItemId = scope_identity(); --if you use an instead of trigger,
                                          --you will have to use name as a key
                                          --to do the identity "grab" in a SELECT
                                          --query
    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH 

   --if the tran is doomed, and the entryTrancount was 0,
   --we have to roll back    
    IF xact_state()= -1 and @entryTrancount = 0 
        ROLLBACK TRANSACTION;
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         ROLLBACK TRANSACTION @savepoint;
         COMMIT TRANSACTION;
       END

    DECLARE @ERRORmessage nvarchar(4000);
    SET @ERRORmessage = 'Error occurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + '''';
    --change to RAISERROR (50000, @ERRORmessage,16) if you want to continue processing
    THROW 50000,@ERRORmessage, 16;
    
    RETURN -100;
  END CATCH
END;
GO



DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Burger',
                                        @description = 'Mmmm Burger',
                                        @newFoodItemId = @foodItemId output
SELECT  @retval as returnValue
IF @retval >= 0
    SELECT  foodItemId, name, description
    FROM    menu.foodItem
    where   foodItemId = @foodItemId

GO

DECLARE @foodItemId int, @retval int;
EXECUTE @retval = menu.foodItem$insert  @name ='Burger',
                                        @description = 'Mmmm Burger',
                                        @newFoodItemId = @foodItemId output;
SELECT  @retval as returnValue;
IF @retval >= 0
    SELECT  foodItemId, name, description
    FROM    menu.foodItem
    where   foodItemId = @foodItemId;
GO

DECLARE @foodItemId int, @retval int;
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = '',
                                        @newFoodItemId = @foodItemId output;
SELECT  @retval as returnValue;
IF @retval >= 0
    SELECT  foodItemId, name, description
    FROM    menu.foodItem
    where   foodItemId = @foodItemId;
GO

--==================================

CREATE TRIGGER menu.foodItem$InsertTrigger
ON menu.foodItem
AFTER INSERT
AS
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
        --[validation blocks][validation section]
        THROW 50000, 'FoodItem''s cannot be done that way',16
       --[modification blocks][modification section]
   END TRY

   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW;

     END CATCH
END

GO
alter PROCEDURE menu.foodItem$insert
(
    @name   varchar(30),
    @description varchar(60),
    @newFoodItemId int = null output --we will send back the new id here
)
AS
BEGIN
  SET NOCOUNT ON;

  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3));
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount;

  BEGIN TRY
    BEGIN TRANSACTION;
    SAVE TRANSACTION @savepoint;

    INSERT INTO menu.foodItem(name, description)
    VALUES (@name, @description);

    SET @newFoodItemId = scope_identity() --if you use an instead of trigger,
                                          --you will have to use name as a key
                                          --to do the identity "grab" in a SELECT
                                          --query
    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH 
   
   select 'In Error Handler';

   --if the tran is doomed, and the entryTrancount was 0,
   --we have to roll back    
    IF xact_state()= -1 and @entryTrancount = 0
     begin  
        SELECT 'Transaction Doomed';
        ROLLBACK TRANSACTION;
     end
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         SELECT 'Savepoint Rollback';
         ROLLBACK TRANSACTION @savepoint;
         COMMIT TRANSACTION;
       END


    DECLARE @ERRORmessage nvarchar(4000);
    SET @ERRORmessage = 'Error occurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + '''';
    --change to RAISERROR (50000, @ERRORmessage,16) if you want to continue processing
    THROW 50000,@ERRORmessage, 16;
    
    RETURN -100;
  END CATCH
END
GO
DECLARE @foodItemId int, @retval int;
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = '',
                                        @newFoodItemId = @foodItemId output;
GO

DECLARE @foodItemId int, @retval int;
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = 'Yummy Big Burger',
                                        @newFoodItemId = @foodItemId output;
SELECT @retval;

GO

ALTER TRIGGER menu.foodItem$InsertTrigger
ON menu.foodItem
AFTER INSERT
AS
BEGIN
   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return
  
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   THROW 50000,'FoodItem''s cannot be done that way',16;
 
END;
GO
DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = 'Yummy Big Burger',
                                        @newFoodItemId = @foodItemId output
SELECT @retval
GO

--=======================================

CREATE TABLE dbo.testIsolationLevel
(
   testIsolationLevelId int identity(1,1)
                CONSTRAINT PKtestIsolationLevel PRIMARY KEY,
   value varchar(10)
);

INSERT dbo.testIsolationLevel(value)
VALUES ('Value1'),
       ('Value2');
GO


SELECT  CASE transaction_isolation_level
            WHEN 1 THEN 'Read Uncomitted'      WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'      WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'             ELSE 'Unspecified'
         END
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid;

GO

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT  CASE transaction_isolation_level
            WHEN 1 THEN 'Read Uncomitted'      WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'      WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'             ELSE 'Unspecified'
         END
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid;
GO

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED --this is the default, just 
                                               --setting for emphasis
BEGIN TRANSACTION
INSERT INTO dbo.testIsolationLevel(value)
VALUES('Value3')

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT *
FROM dbo.testIsolationLevel
Go

--CONNECTION A

COMMIT TRANSACTION
GO
--====
--CONNECTION A

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;
SELECT * FROM dbo.testIsolationLevel;

GO

--CONNECTION B

DELETE FROM dbo.testIsolationLevel
WHERE testIsolationLevelId = 1;


--CONNECTION A
SELECT *
FROM dbo.testIsolationLevel;
COMMIT TRANSACTION;

GO

--=====

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;
SELECT * FROM dbo.testIsolationLevel;

GO

--CONNECTION B

INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value4');
GO


--CONNECTION B
DELETE FROM dbo.testIsolationLevel
WHERE value = 'Value3';

--CONNECTION A

SELECT * FROM dbo.testIsolationLevel;
COMMIT TRANSACTION;
GO
--CONNECTION A

SELECT * FROM dbo.testIsolationLevel;

--===========================================

SELECT *
FROM dbo.testIsolationLevel;
GO

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;
SELECT * FROM dbo.testIsolationLevel;


--CONNECTION B

INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value5');
GO

--CONNECTION A

SELECT * FROM dbo.testIsolationLevel;
COMMIT TRANSACTION;

GO


SELECT * FROM dbo.testIsolationLevel

--===
ALTER DATABASE tempDb
     SET ALLOW_SNAPSHOT_ISOLATION ON;

GO

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
SELECT * FROM dbo.testIsolationLevel;
GO

--CONNECTION B

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO dbo.testIsolationLevel(value);
VALUES ('Value6');
GO


--CONNECTION B

DELETE FROM dbo.testIsolationLevel
WHERE  value = 'Value4';
GO

--CONNECTION A

SELECT * FROM dbo.testIsolationLevel;
GO

--CONNECTION A

UPDATE  dbo.testIsolationLevel
SET     value = 'Value2-mod'
WHERE   testIsolationLevelId = 2;
GO

--CONNECTION B
SELECT * FROM dbo.testIsolationLevel

--CONNECTION A

COMMIT TRANSACTION;
SELECT * FROM dbo.testIsolationLevel;
GO




--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

--touch the data
SELECT * FROM dbo.testIsolationLevel;

GO

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ COMMITTED --any will do

UPDATE dbo.testIsolationLevel
SET    value = 'Value5-mod'
WHERE  testIsolationLevelId = 5 --might be different in yours

GO

--CONNECTION A

UPDATE dbo.testIsolationLevel
SET   value = 'Value5-mod'
WHERE testIsolationLevelId = 5; --might be different in yours

GO
rollback --clean up from the examples.. Shouldn't be necessary, but
         --just in case you have missed something somewhere..
--==================================================================

GO

--CONNECTION A

BEGIN TRANSACTION;
   DECLARE @result int;
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Exclusive';
   SELECT @result;


--CONNECTION B
BEGIN TRANSACTION;
   DECLARE @result int;
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Exclusive';
   SELECT @result;

--CONNECTION B

BEGIN TRANSACTION
SELECT  APPLOCK_TEST('public','invoiceId=1','Exclusive','Transaction')
                                                        as CanTakeLock;
ROLLBACK TRANSACTION;

GO
--CONNECTION A

ROLLBACK TRANSACTION;
GO
--==================================

CREATE TABLE applock
(
    applockId int CONSTRAINT PKapplock PRIMARY KEY,  
                                --the value that we will be generating 
                                --with the procedure
    connectionId int,           --holds the spid of the connection so you can 
                                --who creates the row
    insertTime datetime2(3) DEFAULT (SYSDATETIME()) --the time the row was created, so 
                                                    --you can see the progression
);

GO



CREATE PROCEDURE applock$test
(
    @connectionId int,
    @useApplockFlag bit = 1,
    @stepDelay varchar(10) = '00:00:00'
) as
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION
        DECLARE @retval int = 1;
        IF @useApplockFlag = 1 --turns on and off the applock for testing
            BEGIN
                EXEC @retval = sp_getapplock @Resource = 'applock$test', 
                                                    @LockMode = 'exclusive'; 
                IF @retval < 0 
                    BEGIN
                        DECLARE @errorMessage nvarchar(200);
                        SET @errorMessage = CASE @retval
                                    WHEN -1 THEN 'Applock request timed out.'
                                    WHEN -2 THEN 'Applock request canceled.'
                                    WHEN -3 THEN 'Applock involved in deadlock'
                                ELSE 'Parameter validation or other call error.'
                                             END;
                        THROW 50000,@errorMessage,16;
                    END;
            END;

    --get the next primary key value. Reality case is a far more complex number generator
	--that couldn't be done with a sequence or identity
    DECLARE @applockId int ;   
    SET @applockId = COALESCE((SELECT MAX(applockId) FROM applock),0) + 1 ;

    --delay for parameterized amount of time to slow down operations 
    --and guarantee concurrency problems
    WAITFOR DELAY @stepDelay; 

    --insert the next value
    INSERT INTO applock(applockId, connectionId)
    VALUES (@applockId, @connectionId); 

    --won't have much effect on this code, since the row will now be 
    --exclusively locked, and the max will need to see the new row to 
    --be of any effect.
	IF @useApplockFlag = 1 --turns on and off the applock for testing
		EXEC @retval = sp_releaseapplock @Resource = 'applock$test'; 

    --this releases the applock too
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    --if there is an error, roll back and display it.
    IF @@trancount > 0
        ROLLBACK transaction;
        SELECT cast(error_number() as varchar(10)) + ':' + error_message();
END CATCH  

GO
WAITFOR TIME '21:47'; --set for a time to run so multiple batches 
                            --can simultaneously execute
go
EXEC applock$test @connectionId = @@spid, 
                  @useApplockFlag = 1 -- <1=use applock, 0 = don't use applock>
             ,@stepDelay = '00:00:00.001'; --'delay in hours:minutes:seconds.parts of seconds'
GO 10000 --runs the batch 10000 times in SSMS

--=====================================================
GO


CREATE SCHEMA hr;
GO
CREATE TABLE hr.person
(
     personId int IDENTITY(1,1) CONSTRAINT PKperson primary key,
     firstName varchar(60) NOT NULL,
     middleName varchar(60) NOT NULL,
     lastName varchar(60) NOT NULL,

     dateOfBirth date NOT NULL,
     rowLastModifyTime datetime2(3) NOT NULL
         CONSTRAINT DFLTperson_rowLastModifyTime DEFAULT (SYSDATETIME()),
     rowModifiedByUserIdentifier nvarchar(128) NOT NULL
         CONSTRAINT DFLTperson_rowModifiedByUserIdentifier default suser_sname()

);


GO


CREATE TRIGGER hr.person$InsteadOfUpdate
ON hr.person
INSTEAD OF UPDATE AS
BEGIN

    --stores the number of rows affected
   DECLARE @rowsAffected int = @@rowcount,
           @msg varchar(2000) = '';    --used to hold the error message

      --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --remember to update ALL columns when building instead of triggers
          UPDATE hr.person
          SET    firstName = inserted.firstName,
                 middleName = inserted.middleName,
                 lastName = inserted.lastName,
                 dateOfBirth = inserted.dateOfBirth,
                 rowLastModifyTime = default, -- set the value to the default
                 rowModifiedByUserIdentifier = default 
          FROM   hr.person                              
                     JOIN inserted
                             on hr.person.personId = inserted.personId;
   END TRY
      BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END

GO



INSERT INTO hr.person (firstName, middleName, lastName, dateOfBirth)
VALUES ('Paige','O','Anxtent','19391212');

SELECT *
FROM   hr.person;

GO

UPDATE hr.person
SET     middleName = 'Ona'
WHERE   personId = 1;

SELECT rowLastModifyTime
FROM   hr.person;

GO


ALTER TABLE hr.person
     ADD rowversion rowversion;
GO
SELECT personId, rowversion
FROM   hr.person;
GO



UPDATE  hr.person
SET     firstName = 'Paige' --no actual change occurs
WHERE   personId = 1;
GO


SELECT personId, rowversion,*
FROM   hr.person;

--======

UPDATE  hr.person
SET     firstName = 'Headley'
WHERE   personId = 1  --include the key
  and   firstName = 'Paige'
  and   middleName = 'ona'
  and   lastName = 'Anxtent'
  and   dateOfBirth = '19391212';
GO

UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  --include the key
  and   rowLastModifyTime = '2011-09-14 22:05:58.970';

UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1
  and   rowversion = 0x00000000000007D9;

GO
select *
from   hr.person
GO




CREATE SCHEMA invoicing;
GO
--leaving off who invoice is for, like an account or person name
CREATE TABLE invoicing.invoice
(
     invoiceId int IDENTITY(1,1),
     number varchar(20) NOT NULL,
     objectVersion rowversion not null,
     constraint PKinvoicing_invoice primary key (invoiceId)
);
--also forgetting what product that the line item is for
CREATE TABLE invoicing.invoiceLineItem

(
     invoiceLineItemId int NOT NULL,
     invoiceId int NULL,
     itemCount int NOT NULL,
     cost int NOT NULL,
      CONSTRAINT PKinvoicing_invoiceLineItem primary key (invoiceLineItemId),
      CONSTRAINT FKinvoicing_invoiceLineItem$references$invoicing_invoice
            FOREIGN KEY (invoiceId) REFERENCES invoicing.invoice(invoiceId)
);

GO

CREATE PROCEDURE invoiceLineItem$del
(
    @invoiceId int, --we pass this because the client should have it
                    --with the invoiceLineItem row
    @invoiceLineItemId int,
    @objectVersion rowversion
) as
  BEGIN
    --gives us a unique savepoint name, trim it to 125
    --characters if the user named it really large
    DECLARE @savepoint nvarchar(128) = 
                          cast(object_name(@@procid) AS nvarchar(125)) +
                                         cast(@@nestlevel AS nvarchar(3));
    --get initial entry level, so we can do a rollback on a doomed transaction
    DECLARE @entryTrancount int = @@trancount;

    BEGIN TRY
        BEGIN TRANSACTION;
        SAVE TRANSACTION @savepoint;

        UPDATE  invoice
        SET     number = number
        WHERE   invoiceId = @invoiceId
          And   objectVersion = @objectVersion;


        DELETE  invoiceLineItem
        FROM    invoiceLineItem
        WHERE   invoiceLineItemId = @invoiceLineItemId;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        --if the tran is doomed, and the entryTrancount was 0,
        --we have to roll back    
        IF xact_state()= -1 and @entryTrancount = 0 
            ROLLBACK  TRANSACTION;
        --otherwise, we can still save the other activities in the
       --transaction.
       ELSE IF xact_state() = 1 --transaction not doomed, but open
         BEGIN
             ROLLBACK TRANSACTION @savepoint;
             COMMIT TRANSACTION;
         END

		DECLARE @ERRORmessage nvarchar(4000)
		SET @ERRORmessage = 'Error occurred in procedure ''' + 
			  object_name(@@procid) + ''', Original Message: ''' 
			  + ERROR_MESSAGE() + '''';
		THROW 50000,@ERRORmessage,16;
		RETURN -100;

     END CATCH
 END

 GO

