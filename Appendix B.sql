CREATE DATABASE TriggerDemo
GO
USE TriggerDemo
GO

CREATE SCHEMA Utility;
GO
CREATE TABLE Utility.ErrorLog(
        ErrorLogId int NOT NULL IDENTITY CONSTRAINT PKErrorLog PRIMARY KEY,
		Number int NOT NULL,
        Location sysname NOT NULL,
        Message varchar(4000) NOT NULL,
        LogTime datetime2(3) NULL
              CONSTRAINT dfltErrorLog_error_date  DEFAULT (sysdatetime()),
        ServerPrincipal sysname NOT NULL
              --use original_login to capture the user name of the actual user
              --not a user they have impersonated
              CONSTRAINT dfltErrorLog_error_user_name DEFAULT (original_login())
);
GO
CREATE PROCEDURE Utility.ErrorLog$Insert
(
        @ERROR_NUMBER int,
        @ERROR_LOCATION sysname,
        @ERROR_MESSAGE varchar(4000)
) as
 BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
           INSERT INTO utility.ErrorLog(Number, Location,Message)
           SELECT @ERROR_NUMBER,COALESCE(@ERROR_LOCATION,'No Object'),@ERROR_MESSAGE;
        END TRY
        BEGIN CATCH
           INSERT INTO utility.ErrorLog(Number, Location, Message)
           VALUES (-100, 'utility.ErrorLog$insert',
                        'An invalid call was made to the error log procedure ' + ERROR_MESSAGE());
        END CATCH
END;
--GO
----test the error block we will use
--BEGIN TRY
--    THROW 50000,'Test error',16;
--END TRY
--BEGIN CATCH
--    IF @@trancount > 0
--        ROLLBACK TRANSACTION;

--    --[Error logging section]
--	DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),@ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
--	        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
--	EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

--    THROW; --will halt the batch or be caught by the caller's catch block

--END CATCH
--GO

CREATE TABLE test
(
     testId int
) ;
GO


CREATE TRIGGER test$InsertUpdateDeleteTrigger
ON test
AFTER INSERT, UPDATE, DELETE AS
BEGIN
	 DECLARE @rowcount int = @@rowcount,    --stores the number of rows affected
	         @rowcountInserted int = (select count(*) from inserted),
	         @rowcountDeleted int = (select count(*) from deleted);
     
	 SELECT @rowcount as [@@rowcount], 
	        @rowcountInserted as [@rowcountInserted],
	        @rowcountDeleted as [@rowcountDeleted],
			CASE WHEN @rowcountInserted = 0 THEN 'DELETE'
			     WHEN @rowcountDeleted = 0 THEN 'INSERT'
				 ELSE 'UPDATE' END as Operation;
END

GO
EXEC sp_configure 'show advanced options',1;
RECONFIGURE;
GO 
EXEC sp_configure 'disallow results from triggers',0 
RECONFIGURE;
GO


INSERT INTO test
VALUES (1),(2);
GO


WITH   testMerge as (SELECT *
                     FROM   (Values(2),(3)) as testMerge (testId))
MERGE  test
USING  (SELECT testId FROM testMerge) AS source (testId)
        ON (test.testId = source.testId)
WHEN MATCHED THEN  
	UPDATE SET testId = source.testId
WHEN NOT MATCHED THEN
	INSERT (testId) VALUES (Source.testId)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;
Go

--================================================

CREATE SCHEMA Example
GO
--this is the “transaction” table 
CREATE TABLE Example.AfterTriggerExample
(
        AfterTriggerExampleId  int  CONSTRAINT PKAfterTriggerExample PRIMARY KEY,
        GroupingValue          varchar(10) NOT NULL,
        Value                  int NOT NULL
)
GO

--this is the table that holds the summary data
CREATE TABLE Example.AfterTriggerExampleGroupBalance
(
        GroupingValue  varchar(10) NOT NULL 
                 CONSTRAINT PKAfterTriggerExampleGroupBalance PRIMARY KEY,
        Balance        int NOT NULL
) 
GO



CREATE TRIGGER Example.AfterTriggerExample$InsertTrigger
ON Example.AfterTriggerExample
AFTER INSERT AS
BEGIN

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --           @rowsAffected int = (SELECT COUNT(*) from deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section] 
          --Use a WHERE EXISTS to inserted to make sure not to duplicate rows in the set
          --if > 1 row is modified for the same grouping value
          IF EXIStS (SELECT AfterTriggerExample.GroupingValue
                     FROM   Example.AfterTriggerExample
                     WHERE  EXISTS (SELECT *
                                    FROM Inserted 
                                    WHERE  AfterTriggerExample.GroupingValue = 
                                                                   Inserted.Groupingvalue)
                                    GROUP  BY AfterTriggerExample.GroupingValue
                                    HAVING SUM(Value) < 0)
             BEGIN
                   IF @rowsAffected = 1
                         SELECT @msg = CONCAT('Grouping Value "', GroupingValue, 
                                    '" balance value after operation must be greater than 0')
                         FROM   inserted;
                   ELSE
                          SELECT @msg = CONCAT('The total for the grouping value must ',
                                               'be greater than 0');
                   THROW  50000, @msg, 16;
              END;
                         
          --[modification section]
          --get the balance for any Grouping Values used in the DML statement
          WITH GroupBalance AS
          (SELECT  AfterTriggerExample.GroupingValue, SUM(Value) as NewBalance
           FROM   Example.AfterTriggerExample
           WHERE  EXISTS (SELECT *
                          FROM Inserted 
                          WHERE  AfterTriggerExample.GroupingValue = Inserted.Groupingvalue)
           GROUP  BY AfterTriggerExample.GroupingValue )

         --use merge because there may not be an existing balance row for the grouping value
          MERGE Example.AfterTriggerExampleGroupBalance
          USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                                    AS source (GroupingValue, NewBalance)
          ON    (AfterTriggerExampleGroupBalance.GroupingValue = source.GroupingValue)
         WHEN MATCHED THEN --a grouping value already existed
                 UPDATE SET Balance = source.NewBalance
         WHEN NOT MATCHED THEN --this is a new grouping value
                 INSERT (GroupingValue, Balance)
                 VALUES (Source.GroupingValue, Source.NewBalance);
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                   @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                   @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
          EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END;

GO

INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (1,'Group A',100);
GO
INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (2,'Group A',-50);
GO


INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (3,'Group A',-100);
GO


INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (3,'Group A',10),(4,'Group A',-100);
GO

SELECT *
FROM   utility.ErrorLog;
GO
INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (5,'Group A',100), 
       (6,'Group B',200),
       (7,'Group B',150);


SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

SELECT GroupingValue, SUM(Value) as Balance
FROM   Example.AfterTriggerExample
GROUP BY GroupingValue;


GO

CREATE TRIGGER Example.AfterTriggerExample$UpdateTrigger
ON Example.AfterTriggerExample
AFTER UPDATE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] 
          --Use a WHERE EXISTS to inserted to make sure not to duplicate rows in the set
          --if > 1 row is modified for the same grouping value
          IF EXIStS (SELECT AfterTriggerExample.GroupingValue
                     FROM   Example.AfterTriggerExample
                    --need to check total on any rows that were modified, even if key change
                     WHERE  EXISTS (SELECT *                                                                           
                                    FROM   Inserted 
                                    WHERE  AfterTriggerExample.GroupingValue = 
                                                                    Inserted.Groupingvalue
                                    UNION ALL
                                    SELECT *
                                    FROM   Deleted
                                    WHERE  AfterTriggerExample.GroupingValue = 
                                                                     Deleted.Groupingvalue)
                                    GROUP  BY AfterTriggerExample.GroupingValue
                                    HAVING SUM(Value) < 0)
                         BEGIN
                             IF @rowsAffected = 1
                                SELECT @msg = CONCAT('Grouping Value "',
                                      COALESCE(inserted.GroupingValue,deleted.GroupingValue),                  
                                    '" balance value after operation must be greater than 0')
                                FROM   inserted --only one row could be returned...
                                          CROSS JOIN deleted;
                            ELSE
                                SELECT @msg = CONCAT('The total for the grouping value ',             
                                                     'must be greater than 0');

                            THROW  50000, @msg, 16;
                        END

          --[modification section]
          --get the balance for any Grouping Values used in the DML statement
          SET ANSI_WARNINGS OFF; --we know we will be summing on a NULL, with no better way
          WITH GroupBalance AS
          (SELECT ChangedRows.GroupingValue, SUM(Value) as NewBalance
           FROM   Example.AfterTriggerExample
           --the right outer join makes sure that we get all groups, even if no data
           --remains in the table for a set
                      RIGHT OUTER JOIN
                              (SELECT GroupingValue
                               FROM Inserted 
                               UNION 
                               SELECT GroupingValue
                               FROM Deleted ) as ChangedRows
                     --the join make sure we only get rows for changed grouping values
                            ON ChangedRows.GroupingValue = AfterTriggerExample.GroupingValue
           GROUP  BY ChangedRows.GroupingValue  )
          --use merge because the user may change the grouping value, and 
          --That could even cause a row in the balance table to need to be deleted
          MERGE Example.AfterTriggerExampleGroupBalance
          USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                          AS source (GroupingValue, NewBalance)
          ON (AfterTriggerExampleGroupBalance.GroupingValue = source.GroupingValue)
          WHEN MATCHED and Source.NewBalance IS NULL --should only happen with changed key
                    THEN DELETE
          WHEN MATCHED THEN --normal case, where an amount was updated
                    UPDATE SET Balance = source.NewBalance
                    WHEN NOT MATCHED THEN --should only happen with changed 
                                          --key that didn't previously exist
                         INSERT (GroupingValue, Balance)
                          VALUES (Source.GroupingValue, Source.NewBalance);
                        
          SET ANSI_WARNINGS ON; --restore proper setting, even if you don’t need to
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION

      --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                  @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                  @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
          EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END ;
GO


UPDATE Example.AfterTriggerExample
SET    Value = 50 --Was 100
where  AfterTriggerExampleId = 5;
GO


SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--Changing the key
UPDATE Example.AfterTriggerExample
SET    GroupingValue = 'Group C'
WHERE  GroupingValue = 'Group B';
GO


SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--all rows
UPDATE Example.AfterTriggerExample
SET    Value = 10 ;
GO

SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO


--violate business rules
UPDATE Example.AfterTriggerExample
SET    Value = -10 ; 
GO


CREATE TRIGGER Example.AfterTriggerExample$DeleteTrigger
ON Example.AfterTriggerExample
AFTER DELETE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   --      @rowsAffected int = (SELECT COUNT(*) FROM inserted);
                 @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section] 
          --Use a WHERE EXISTS to inserted to make sure not to duplicate rows in the set
          --if > 1 row is modified for the same grouping value
         IF EXIStS (SELECT AfterTriggerExample.GroupingValue
                    FROM   Example.AfterTriggerExample
                    WHERE  EXISTS (SELECT * --delete trigger only needs check deleted rows
                                   FROM   Deleted
                                    WHERE  AfterTriggerExample.GroupingValue = 
                                                                     Deleted.Groupingvalue)
                    GROUP  BY AfterTriggerExample.GroupingValue
                    HAVING SUM(Value) < 0)
           BEGIN
                IF @rowsAffected = 1
                      SELECT @msg = CONCAT('Grouping Value "', GroupingValue, 
                                    '" balance value after operation must be greater than 0')
                      FROM   deleted; --use deleted for deleted trigger
                ELSE
                  SELECT @msg = 'The total for the grouping value must be greater than 0';

                THROW  50000, @msg, 16;
          END

          --[modification section]
          --get the balance for any Grouping Values used in the DML statement
           SET ANSI_WARNINGS OFF; --we know we will be summing on a NULL, with no better way
           WITH GroupBalance AS
           (SELECT ChangedRows.GroupingValue, SUM(Value) as NewBalance
            FROM   Example.AfterTriggerExample
            --the right outer join makes sure that we get all groups, even if no data
            --remains in the table for a set
                       RIGHT OUTER JOIN
                              (SELECT GroupingValue
                               FROM Deleted ) as ChangedRows
                           --the join make sure we only get rows for changed grouping values
                            ON ChangedRows.GroupingValue = AfterTriggerExample.GroupingValue
           GROUP  BY ChangedRows.GroupingValue)

          --use merge because the delete may or may not remove the last row for a 
          --group which could even cause a row in the balance table to need to be deleted
           MERGE Example.AfterTriggerExampleGroupBalance
           USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                                   AS source (GroupingValue, NewBalance)
           ON (AfterTriggerExampleGroupBalance.GroupingValue = source.GroupingValue)
          WHEN MATCHED and Source.NewBalance IS Null --you have deleted the last key
                  THEN DELETE
          WHEN MATCHED THEN --there were still rows left after the delete
                  UPDATE SET Balance = source.NewBalance;
                        
          SET ANSI_WARNINGS ON; --restore proper setting
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                  @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                  @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
          EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


UPDATE Example.AfterTriggerExample
SET    Value = -5
WHERE  AfterTriggerExampleId in (2,5); 

UPDATE Example.AfterTriggerExample
SET    Value = -10
WHERE  AfterTriggerExampleId  = 6;
GO

SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId = 1;
GO

DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId in (1,7);
GO

DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId = 6;

SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO


INSERT INTO Example.AfterTriggerExample
VALUES (8, 'Group B',10);
GO


SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO


DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId in (1,2,5);
GO


SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

DELETE FROM Example.AfterTriggerExample;
GO


SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO


--===============================================================

CREATE TABLE Example.InsteadOfTriggerExample
(
        InsteadOfTriggerExampleId  int NOT NULL 
                        CONSTRAINT PKInsteadOfTriggerExample PRIMARY KEY,
        FormatUpper  varchar(30) NOT NULL,
        RowCreatedTime datetime2(3) NOT NULL,
        RowLastModifyTime datetime2(3) NOT NULL
);

GO

CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfInsertTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
          @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --     @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> --this is all I change other than the name and table in the
                              --trigger declaration/heading
          INSERT INTO Example.InsteadOfTriggerExample                
                      (InsteadOfTriggerExampleId,FormatUpper,
                       RowCreatedTime,RowLastModifyTime)
          --uppercase the FormatUpper column, set the %time columns to system time
           SELECT InsteadOfTriggerExampleId, UPPER(FormatUpper),
                  sysdatetime(),sysdatetime()                                                                 
           FROM   Inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
               @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
               @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
      EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (1,'not upper at all');
GO

SELECT *
FROM   Example.InsteadOfTriggerExample;
GO

INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (2,'UPPER TO START'),(3,'UpPeRmOsT tOo!');
GO


SELECT *
FROM   Example.InsteadOfTriggerExample;
GO

--causes an error
INSERT INTO Example.InsteadOfTriggerExample (InsteadOfTriggerExampleId,FormatUpper)
VALUES (4,NULL) ;
GO



CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfUpdateTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF UPDATE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
         @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --    @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> 
          --note, this trigger assumes non-editable keys. Consider adding a surrogate key
          --(even non-pk) if you need to be able to modify key values
          UPDATE InsteadOfTriggerExample 
          SET    FormatUpper = UPPER(Inserted.FormatUpper),
                 --RowCreatedTime, Leave this value out to make sure it was updated
                 RowLastModifyTime = SYSDATETIME()
          FROM   Inserted
                   JOIN Example.InsteadOfTriggerExample 
                       ON Inserted.InsteadOfTriggerExampleId = 
                                 InsteadOfTriggerExample.InsteadOfTriggerExampleId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
               @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
               @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
      EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW;--will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


UPDATE  Example.InsteadOfTriggerExample
SET     RowCreatedTime = '1900-01-01',
        RowLastModifyTime = '1900-01-01',
        FormatUpper = 'final test'
WHERE   InsteadOfTriggerExampleId in (1,2);
GO


SELECT *
FROM   Example.InsteadOfTriggerExample;
GO



CREATE TABLE testIdentity
(
	testIdentityId int IDENTITY CONSTRAINT PKtestIdentity PRIMARY KEY,
	value varchar(30) CONSTRAINT AKtestIdentity UNIQUE,
);
GO


INSERT INTO testIdentity(value)
VALUES ('without trigger');

SELECT SCOPE_IDENTITY() as scopeIdentity;
GO

CREATE TRIGGER testIdentity$InsteadOfInsertTrigger
ON testIdentity
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
	  INSERT INTO testIdentity(value)
          SELECT value
          FROM   inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
               @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
               @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
      EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW ;--will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

INSERT INTO testIdentity(value)
VALUES ('with trigger');

SELECT scope_identity() as scopeIdentity;
GO


INSERT INTO testIdentity(value)
VALUES ('with trigger two');

SELECT testIdentityId as scopeIdentity
FROM   testIdentity
WHERE  value = 'with trigger two'; --use an alternate key
GO

