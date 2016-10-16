create database Chapter7
GO
use Chapter7
GO

CREATE SCHEMA Music;
GO
CREATE TABLE Music.Artist
(
   ArtistId int NOT NULL,
   Name varchar(60) NOT NULL,

   CONSTRAINT PKMusic_Artist PRIMARY KEY CLUSTERED (ArtistId),
   CONSTRAINT PKMusic_Artist_Name UNIQUE NONCLUSTERED (Name)
);
CREATE TABLE Music.Publisher
(
        PublisherId              int NOT NULL primary key,
        Name                     varchar(20) NOT NULL,
        CatalogNumberMask        varchar(100) NOT NULL
        CONSTRAINT DfltMusic_Publisher_CatalogNumberMask default ('%'),
        CONSTRAINT AKMusic_Publisher_Name UNIQUE NONCLUSTERED (Name),
);

CREATE TABLE Music.Album
(
       AlbumId int NOT NULL,
       Name varchar(60) NOT NULL,
       ArtistId int NOT NULL,
       CatalogNumber varchar(20) NOT NULL,
       PublisherId int NOT NULL --not requiring this information

       CONSTRAINT PKMusic_Album PRIMARY KEY CLUSTERED(AlbumId),
       CONSTRAINT AKMusic_Album_Name UNIQUE NONCLUSTERED (Name),
       CONSTRAINT FKMusic_Artist$records$Music_Album
            FOREIGN KEY (ArtistId) REFERENCES Music.Artist(ArtistId),
       CONSTRAINT FKMusic_Publisher$published$Music_Album
            FOREIGN KEY (PublisherId) REFERENCES Music.Publisher(PublisherId)
);


INSERT  INTO Music.Publisher (PublisherId, Name, CatalogNumberMask)
VALUES (1,'Capitol',
        '[0-9][0-9][0-9]-[0-9][0-9][0-9a-z][0-9a-z][0-9a-z]-[0-9][0-9]'),
        (2,'MCA', '[a-z][a-z][0-9][0-9][0-9][0-9][0-9]');

INSERT  INTO Music.Artist(ArtistId, Name)
VALUES (1, 'The Beatles'),(2, 'The Who');

INSERT INTO Music.Album (AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES (1, 'The White Album',1,1,'433-43ASD-33'),
       (2, 'Revolver',1,1,'111-11111-11'),
       (3, 'Quadrophenia',2,2,'CD12345');
GO


ALTER TABLE Music.Artist WITH CHECK
   ADD CONSTRAINT chkMusic_Artist$Name$NoPetShopNames
           CHECK (Name not like '%Pet%Shop%');


GO
INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Pet Shop Boys');
GO
INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Madonna');
GO

select 'expected error follows';
go
ALTER TABLE Music.Artist WITH CHECK
   ADD CONSTRAINT chkMusic_Artist$Name$noMadonnaNames
           CHECK (Name not like '%Madonna%');


ALTER TABLE Music.Artist WITH NOCHECK
   ADD CONSTRAINT chkMusic_Artist$Name$noMadonnaNames
           CHECK (Name not like '%Madonna%');
GO
UPDATE Music.Artist
SET Name = Name;
GO

SELECT Definition, is_not_trusted
FROM   sys.check_constraints
WHERE  object_schema_name(object_id) = 'Music'
  AND  name = 'chkMusic_Artist$Name$noMadonnaNames';
GO

ALTER TABLE Music.Artist WITH CHECK CHECK CONSTRAINT chkMusic_Artist$Name$noMadonnaNames;
GO
DELETE FROM  Music.Artist
WHERE  Name = 'Madonna';
GO
ALTER TABLE Music.Artist WITH CHECK CHECK CONSTRAINT chkMusic_Artist$Name$noMadonnaNames;
GO
ALTER TABLE Music.Artist NOCHECK CONSTRAINT chkMusic_Artist$Name$noMadonnaNames;
GO

SELECT definition, is_not_trusted, is_disabled
FROM   sys.check_constraints
WHERE  object_schema_name(object_id) = 'Music'
  AND  name = 'chkMusic_Artist$Name$noMadonnaNames';

GO

ALTER TABLE Music.Artist WITH CHECK CHECK CONSTRAINT chkMusic_Artist$Name$noMadonnaNames;
GO


ALTER TABLE Music.Album WITH CHECK
   ADD CONSTRAINT chkMusicAlbum$Name$noEmptyString
           CHECK (LEN(Name) > 0); --note,len does a trim by default, so any string 
                                  --of all space characters will return 0
GO

INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 4, '', 1, 1,'dummy value' );
GO
DELETE FROM Music.Album
WHERE  Name = ''
GO
ALTER TABLE Music.Album WITH CHECK
   ADD CONSTRAINT chkMusicAlbum$Name$noEmptyString
           CHECK (LEN(RTRIM(Name)) > 0)
GO
INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 4, '', 1, 1,'dummy value' )
GO


CREATE FUNCTION Music.Publisher$CatalogNumberValidate
(
   @CatalogNumber char(12),
   @PublisherId int --now based on the Artist ID
)

RETURNS bit
AS
BEGIN
   DECLARE @LogicalValue bit, @CatalogNumberMask varchar(100);

   SELECT @LogicalValue = CASE WHEN @CatalogNumber LIKE CatalogNumberMask
                                      THEN 1
                               ELSE 0  END
   FROM   Music.Publisher
   WHERE  PublisherId = @PublisherId;

   RETURN @LogicalValue;
END
GO

SELECT Album.CatalogNumber, Publisher.CatalogNumberMask
FROM   Music.Album as Album
         JOIN Music.Publisher as Publisher
            ON Album.PublisherId = Publisher.PublisherId;
GO
ALTER TABLE Music.Album
   WITH CHECK ADD CONSTRAINT
       chkMusicAlbum$CatalogNumber$CatalogNumberValidate
       CHECK (Music.Publisher$CatalogNumbervalidate
                          (CatalogNumber,PublisherId) = 1);
Go

SELECT Album.Name, Album.CatalogNumber, Publisher.CatalogNumberMask
FROM Music.Album AS Album
       JOIN Music.Publisher AS Publisher
         on Publisher.PublisherId = Album.PublisherId
WHERE Music.Publisher$CatalogNumbervalidate(Album.CatalogNumber,Album.PublisherId) = 1;


GO
ALTER TABLE Music.Album
   WITH CHECK ADD CONSTRAINT
       chkMusicAlbum$CatalogNumber$CatalogNumberValidate
       CHECK (Music.Publisher$CatalogNumbervalidate
                          (CatalogNumber,PublisherId) = 1)
GO
INSERT  Music.Album(AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES  (4,'Who''s Next',2,2,'1');

GO

INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
VALUES  (4,'Who''s Next',2,'AC12345',2);

SELECT * FROM Music.Album;
GO


SELECT *
FROM   Music.Album AS Album
          JOIN Music.Publisher AS Publisher
                on Publisher.PublisherId = Album.PublisherId
WHERE  Music.Publisher$CatalogNumbervalidate
                        (Album.CatalogNumber, Album.PublisherId) <> 1;

GO



CREATE SCHEMA utility; --used to hold objects for utility purposes
GO
CREATE TABLE utility.ErrorMap
(
    ConstraintName sysname NOT NULL primary key,
    Message         varchar(2000) NOT NULL
);
GO
INSERT utility.ErrorMap(constraintName, message)
VALUES ('chkMusicAlbum$CatalogNumber$CatalogNumberValidate',
        'The catalog number does not match the format set up by the Publisher');
GO
CREATE PROCEDURE utility.ErrorMap$MapError
(
    @ErrorNumber  int = NULL,
    @ErrorMessage nvarchar(2000) = NULL,
    @ErrorSeverity INT= NULL

) AS
  BEGIN
    SET NOCOUNT ON

    --use values in ERROR_ functions unless the user passes in values
    SET @ErrorNumber = Coalesce(@ErrorNumber, ERROR_NUMBER());
    SET @ErrorMessage = Coalesce(@ErrorMessage, ERROR_MESSAGE());
    SET @ErrorSeverity = Coalesce(@ErrorSeverity, ERROR_SEVERITY());

    --strip the constraint name out of the error message
    DECLARE @constraintName sysname;
    SET @constraintName = substring( @ErrorMessage,
                             CHARINDEX('constraint "',@ErrorMessage) + 12,
                             CHARINDEX('"',substring(@ErrorMessage,
                             CHARINDEX('constraint "',@ErrorMessage) +
                                                                12,2000))-1)
    --store off original message in case no custom message found
    DECLARE @originalMessage nvarchar(2000);
    SET @originalMessage = ERROR_MESSAGE();

    IF @ErrorNumber = 547 --constraint error
      BEGIN
        SET @ErrorMessage =
                        (SELECT message
                         FROM   utility.ErrorMap
                         WHERE  constraintName = @constraintName
                            ); 
      END

    --if the error was not found, get the original message with generic 50000 error numberd
    SET @ErrorMessage = isNull(@ErrorMessage, @originalMessage);
    THROW  50000, @ErrorMessage, @ErrorSeverity;
  END
GO

GO
BEGIN TRY
     INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
     VALUES  (5,'who are you',2,'badnumber',2);
END TRY
BEGIN CATCH
    EXEC utility.ErrorMap$MapError;
END CATCH
GO



CREATE SCHEMA Accounting;
go
CREATE TABLE Accounting.Account
(
        AccountNumber        char(10) NOT NULL
                  constraint PKAccounting_Account primary key
        --would have other columns
);

CREATE TABLE Accounting.AccountActivity
(
        AccountNumber                char(10) NOT NULL
            constraint Accounting_Account$has$Accounting_AccountActivity
                       foreign key references Accounting.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates
        TransactionNumber            char(20) NOT NULL,
        Date                         datetime2(3) NOT NULL,
        TransactionAmount            numeric(12,2) NOT NULL,
        constraint PKAccounting_AccountActivity
                      PRIMARY KEY (AccountNumber, TransactionNumber)
);

GO


CREATE TRIGGER Accounting.AccountActivity$insertUpdateTrigger
ON Accounting.AccountActivity
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
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
                               AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING SUM(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = 'Account: ' + AccountNumber +
                  ' TransactionNumber:' +
                   cast(TransactionNumber as varchar(36)) +
                   ' for amount: ' + cast(TransactionAmount as varchar(10))+
                   ' cannot be processed as it will cause a negative balance'
             FROM   inserted;
        ELSE
          SELECT @msg = 'One of the rows caused a negative balance';
          THROW  50000, @msg, 16;
      END

   --[modification section]
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO


--create some set up test data
INSERT INTO Accounting.Account(AccountNumber)
VALUES ('1111111111');

INSERT INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000001','20050712',100),
       ('1111111111','A0000000000000000002','20050713',100);

GO

INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000003','20050713',-300);
GO


INSERT  INTO Accounting.Account(AccountNumber)
VALUES ('2222222222');
GO
--Now, this data will violate the constraint for the new Account:
INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100),
       ('2222222222','A0000000000000000005','20050715',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',-201);
GO

SELECT trigger_events.type_desc
FROM sys.trigger_events
         JOIN sys.triggers
                  ON sys.triggers.object_id = sys.trigger_events.object_id
WHERE  triggers.name = 'AccountActivity$insertUpdateTrigger';

GO

ALTER TABLE Accounting.Account 
   ADD BalanceAmount numeric(12,2) NOT NULL
      CONSTRAINT DfltAccounting_Account_BalanceAmount DEFAULT (0.00); 

GO

SELECT  Account.AccountNumber,
        SUM(coalesce(AccountActivity.TransactionAmount,0.00)) AS NewBalance
FROM   Accounting.Account
         LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber;
GO

WITH  Updater as (
SELECT  Account.AccountNumber,
        SUM(coalesce(TransactionAmount,0.00)) as NewBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            On Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber)
UPDATE Account
SET    BalanceAmount = Updater.NewBalance
FROM   Accounting.Account
         JOIN Updater
                on Account.AccountNumber = Updater.AccountNumber;
GO


ALTER TRIGGER Accounting.AccountActivity$insertUpdateTrigger
ON Accounting.AccountActivity
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
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
                               AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING sum(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = 'Account: ' + AccountNumber +
                  ' TransactionNumber:' +
                   cast(TransactionNumber as varchar(36)) +
                   ' for amount: ' + cast(TransactionAmount as varchar(10))+
                   ' cannot be processed as it will cause a negative balance'
             FROM   inserted;
        ELSE
          SELECT @msg = 'One of the rows caused a negative balance';

          THROW  50000, @msg, 16;
      END

    --[modification section]
    IF UPDATE (TransactionAmount)
      BEGIN
        ;WITH  Updater as (
        SELECT  Account.AccountNumber,
                SUM(coalesce(TransactionAmount,0.00)) as NewBalance
        FROM   Accounting.Account
                LEFT OUTER JOIN Accounting.AccountActivity
                    On Account.AccountNumber = AccountActivity.AccountNumber
               --This where clause limits the summarizations to those rows
               --that were modified by the DML statement that caused
               --this trigger to fire.
        WHERE  EXISTS (SELECT *
                       FROM   Inserted
                       WHERE  Account.AccountNumber = Inserted.AccountNumber)
        GROUP  BY Account.AccountNumber)

        UPDATE Account
        SET    BalanceAmount = Updater.NewBalance
        FROM   Accounting.Account
                  JOIN Updater
                      on Account.AccountNumber = Updater.AccountNumber;
	 END


   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO

INSERT  INTO Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100);
GO

SELECT  Account.AccountNumber,Account.BalanceAmount,
        SUM(coalesce(AccountActivity.TransactionAmount,0.00)) AS SummedBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber,Account.BalanceAmount;
GO

INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000005','20050714',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',100);
GO

SELECT  Account.AccountNumber,Account.BalanceAmount,
        SUM(coalesce(AccountActivity.TransactionAmount,0.00)) AS SummedBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber,Account.BalanceAmount;
GO


CREATE TRIGGER Accounting.AccountActivity$deleteTrigger
ON Accounting.AccountActivity
AFTER DELETE AS
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
   --        @rowsAffected int = (select count(*) from inserted)
             @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY

   --[validation section]
   --[modification section]
      ;WITH  Updater as (
            SELECT  Account.AccountNumber,
                    SUM(coalesce(TransactionAmount,0.00)) as NewBalance
            FROM   Accounting.Account
                     LEFT OUTER JOIN Accounting.AccountActivity
                         On Account.AccountNumber = AccountActivity.AccountNumber
            WHERE  EXISTS (SELECT *
                           FROM   deleted
                           WHERE  Account.AccountNumber = 
                                          deleted.AccountNumber)
            GROUP  BY Account.AccountNumber, Account.BalanceAmount)
            UPDATE Account
            SET    BalanceAmount = Updater.NewBalance
            FROM   Accounting.Account
                       JOIN Updater
                           ON  Account.AccountNumber = Updater.AccountNumber;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO


DELETE Accounting.AccountActivity
WHERE  TransactionNumber in ('A0000000000000000004',
                             'A0000000000000000005');
GO

SELECT  Account.AccountNumber,Account.BalanceAmount,
        SUM(coalesce(AccountActivity.TransactionAmount,0.00)) AS SummedBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber,Account.BalanceAmount;
GO




CREATE SCHEMA Internet;
GO
CREATE TABLE Internet.Url
(
    UrlId int not null identity(1,1) constraint PKUrl primary key,
    Name  varchar(60) not null constraint AKInternet_Url_Name UNIQUE,
    Url   varchar(200) not null constraint AKInternet_Url_Url UNIQUE
);

--Not a user manageable table, so not using identity key (as discussed in
--Chapter 5 when I discussed choosing keys) in this one table.  Others are
--using identity-based keys in this example.
CREATE TABLE Internet.UrlStatusType
(
        UrlStatusTypeId  int not null
                      CONSTRAINT PKInternet_UrlStatusType PRIMARY KEY,
        Name varchar(20) NOT NULL
                      CONSTRAINT AKInternet_UrlStatusType UNIQUE,
        DefaultFlag bit NOT NULL,
        DisplayOnSiteFlag bit NOT NULL
); 

CREATE TABLE Internet.UrlStatus
(
        UrlStatusId int not null identity(1,1)
                      CONSTRAINT PKInternet_UrlStatus PRIMARY KEY,
        UrlStatusTypeId int NOT NULL
                      CONSTRAINT
               Internet_UrlStatusType$defines_status_type_of$Internet_UrlStatus
                      REFERENCES Internet.UrlStatusType(UrlStatusTypeId),
        UrlId int NOT NULL
          CONSTRAINT Internet_Url$has_status_history_in$Internet_UrlStatus
                      REFERENCES Internet.Url(UrlId),
        ActiveTime        datetime2(3) NOT NULL,
        CONSTRAINT AKInternet_UrlStatus_statusUrlDate
                      UNIQUE (UrlStatusTypeId, UrlId, ActiveTime)
);

--set up status types
INSERT  Internet.UrlStatusType (UrlStatusTypeId, Name,
                                   DefaultFlag, DisplayOnSiteFlag)
VALUES (1, 'Unverified',1,0),
       (2, 'Verified',0,1),
       (3, 'Unable to locate',0,0);
GO


CREATE TRIGGER Internet.Url$afterInsertTrigger
ON Internet.Url
AFTER INSERT AS
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
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]

          --[modification section]
          --add a row to the UrlStatus table to tell it that the new row
          --should start out as the default status
          INSERT INTO Internet.UrlStatus (UrlId, UrlStatusTypeId, ActiveTime)
          SELECT inserted.UrlId, UrlStatusType.UrlStatusTypeId,
                  SYSDATETIME()
          FROM inserted
                CROSS JOIN (SELECT UrlStatusTypeId
                            FROM   UrlStatusType
                            WHERE  DefaultFlag = 1)  as UrlStatusType;
                                           --use cross join with a WHERE clause
                                           --as this is not technically a join
                                           --between inserted and UrlType
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;
              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;
GO


INSERT  Internet.Url(Name, Url)
VALUES ('More info can be found here',
        'http://sqlblog.com/blogs/louis_davidson/default.aspx');

SELECT * FROM Internet.Url;
SELECT * FROM Internet.UrlStatus;
GO

CREATE SCHEMA Entertainment;
go
CREATE TABLE Entertainment.GamePlatform
(
    GamePlatformId int NOT NULL CONSTRAINT PKEntertainmentGamePlatform PRIMARY KEY,
    Name  varchar(50) NOT NULL CONSTRAINT AKEntertainmentGamePlatform_Name UNIQUE
);
CREATE TABLE Entertainment.Game
(
    GameId  int NOT NULL CONSTRAINT PKEntertainmentGame PRIMARY KEY,
    Name    varchar(50) NOT NULL CONSTRAINT AKEntertainmentGame_Name UNIQUE
    --more details that are common to all platforms
);

--associative entity with cascade relationships back to Game and GamePlatform
CREATE TABLE Entertainment.GameInstance
(
    GamePlatformId int NOT NULL ,
    GameId int NOT NULL ,
    PurchaseDate date NOT NULL,
    CONSTRAINT PKEntertainmentGameInstance PRIMARY KEY (GamePlatformId, GameId),
    CONSTRAINT
    EntertainmentGame$is_owned_on_platform_by$EntertainmentGameInstance
      FOREIGN KEY (GameId) REFERENCES Entertainment.Game(GameId)
                                               ON DELETE CASCADE,
      CONSTRAINT
        EntertainmentGamePlatform$is_linked_to$EntertainmentGameInstance
      FOREIGN KEY (GamePlatformId)
           REFERENCES Entertainment.GamePlatform(GamePlatformId)
                ON DELETE CASCADE
);
GO

INSERT  into Entertainment.Game (GameId, Name)
VALUES (1,'Lego Pirates of the Carribean'),
       (2,'Legend Of Zelda: Ocarina of Time');

INSERT  into Entertainment.GamePlatform(GamePlatformId, Name)
VALUES (1,'Nintendo Wii'),   --Yes, as a matter of fact I am still a
       (2,'Nintendo 3DS');     --Nintendo Fanboy, why do you ask?

INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, PurchaseDate)
VALUES (1,1,'20110804'),
       (1,2,'20110810'),
       (2,2,'20110604');

--the full outer joins ensure that all rows are returned from all sets, leaving
--nulls where data is missing
SELECT  GamePlatform.Name as Platform, Game.Name as Game, GameInstance. PurchaseDate
FROM    Entertainment.Game as Game
            FULL OUTER JOIN Entertainment.GameInstance as GameInstance
                    ON Game.GameId = GameInstance.GameId
            FULL OUTER JOIN Entertainment.GamePlatform
                    ON GamePlatform.GamePlatformId = GameInstance.GamePlatformId;
GO

CREATE TRIGGER Entertainment.GameInstance$afterDeleteTrigger
ON Entertainment.GameInstance
AFTER DELETE AS
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
   --        @rowsAffected int = (select count(*) from inserted)
             @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
        --[validation section] 

        --[modification section]
                         --delete all Games
        DELETE Game      --where the GameInstance was deleted
        WHERE  GameId in (SELECT deleted.GameId
                          FROM   deleted     --and there are no GameInstances
                           WHERE  not exists (SELECT  *        --left
                                              FROM    GameInstance
                                              WHERE   GameInstance.GameId =
                                                               deleted.GameId));
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;
              THROW; --will halt the batch or be caught by the caller's catch block

   END CATCH
END
GO
DELETE Entertainment.GamePlatform
WHERE GamePlatformId = 1;
GO
SELECT GamePlatform.Name AS Platform, Game.Name AS Game, GameInstance. PurchaseDate
FROM Entertainment.Game AS Game
FULL OUTER JOIN Entertainment.GameInstance as GameInstance
ON Game.GameId = GameInstance.GameId
FULL OUTER JOIN Entertainment.GamePlatform
ON GamePlatform.GamePlatformId = GameInstance.GamePlatformId;
GO


CREATE SCHEMA hr;
GO
CREATE TABLE hr.employee
(
    employee_id char(6) NOT NULL CONSTRAINT PKhr_employee PRIMARY KEY,
    first_name  varchar(20) NOT NULL,
    last_name   varchar(20) NOT NULL,
    salary      decimal(12,2) NOT NULL
);
CREATE TABLE hr.employee_auditTrail
(
    employee_id          char(6) NOT NULL,
    date_changed         datetime2(0) NOT NULL --default so we don't have to
                                               --code for it
          CONSTRAINT DfltHr_employee_date_changed DEFAULT (SYSDATETIME()),
    first_name           varchar(20) NOT NULL,
    last_name            varchar(20) NOT NULL,
    salary               decimal(12,2) NOT NULL,
    --the following are the added columns to the original
    --structure of hr.employee
    action               char(6) NOT NULL
          CONSTRAINT chkHr_employee_action --we don't log inserts, only changes
                                          CHECK(action in ('delete','update')),
    changed_by_user_name sysname NOT NULL
                CONSTRAINT DfltHr_employee_changed_by_user_name
                                          DEFAULT (original_login()),
    CONSTRAINT PKemployee_auditTrail PRIMARY KEY (employee_id, date_changed)
);
GO




CREATE TRIGGER hr.employee$updateAndDeleteAuditTrailTrigger
ON hr.employee
AFTER UPDATE, DELETE AS
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
   --        @rowsAffected int = (select count(*) from inserted)
              @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]
          --[modification section]
          --since we are only doing update and delete, we just
          --need to see if there are any rows
          --inserted to determine what action is being done.
          DECLARE @action char(6);
          SET @action = CASE WHEN (SELECT count(*) FROM inserted) > 0
                             THEN 'update' ELSE 'delete' END;

          --since the deleted table contains all changes, we just insert all
          --of the rows in the deleted table and we are done.
          INSERT employee_auditTrail (employee_id, first_name, last_name,
                                     salary, action)
          SELECT employee_id, first_name, last_name, salary, @action
          FROM   deleted;

   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END;

GO

INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (1, 'Phillip','Taibul',10000);
GO


UPDATE hr.employee
SET salary = salary * 1.10 --ten percent raise!
WHERE employee_id = 1;

SELECT *
FROM   hr.employee;
GO

SELECT *
FROM   hr.employee_auditTrail;
GO



CREATE SCHEMA school;
Go
CREATE TABLE school.student
(
      studentId       int identity not null
            CONSTRAINT PKschool_student PRIMARY KEY,
      studentIdNumber char(8) not null
            CONSTRAINT AKschool_student_studentIdNumber UNIQUE,
      firstName       varchar(20) not null,
      lastName        varchar(20) not null,
      --implementation columns, we will code for them in the trigger too
      rowCreateDate   datetime2(3) not null
            CONSTRAINT dfltSchool_student_rowCreateDate
                                 DEFAULT (current_timestamp),
      rowCreateUser   sysname not null
            CONSTRAINT dfltSchool_student_rowCreateUser DEFAULT (current_user)
);
GO

CREATE FUNCTION Utility.TitleCase
(
   @inputString varchar(2000)
)
RETURNS varchar(2000) AS

BEGIN
   -- set the whole string to lower
   SET @inputString = LOWER(@inputstring);
   -- then use stuff to replace the first character
   SET @inputString =
   --STUFF in the uppercased character in to the next character,
   --replacing the lowercased letter
   STUFF(@inputString,1,1,UPPER(SUBSTRING(@inputString,1,1)));

   --@i is for the loop counter, initialized to 2
   DECLARE @i int = 2;

   --loop from the second character to the end of the string
   WHILE @i < LEN(@inputString)
   BEGIN
      --if the character is a space
      IF SUBSTRING(@inputString,@i,1) = ' '
      BEGIN
         --STUFF in the uppercased character into the next character
         SET @inputString = STUFF(@inputString,@i +
                                   1,1,UPPER(SUBSTRING(@inputString,@i + 1,1)));
      END
      --increment the loop counter
      SET @i = @i + 1;
   END
   RETURN @inputString;
END;
GO


CREATE TRIGGER school.student$insteadOfInsertTrigger
ON school.student
INSTEAD OF INSERT AS
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
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName,
                                     rowCreateDate, rowCreateUser)
          SELECT studentIdNumber,
                 Utility.titleCase(firstName),
                 Utility.titleCase(lastName),
                 CURRENT_TIMESTAMP, ORIGINAL_LOGIN()
          FROM  inserted;   --no matter what the user put in the inserted row
   END TRY                  --when the row was created, these values will be inserted
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              THROW; --will halt the batch or be caught by the caller's catch block 

     END CATCH
END
GO

INSERT school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000001','CaPtain', 'von nuLLY');
GO

INSERT school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000002','NORM', 'uLl'),
       ( '0000003','gREy', 'tezine');
GO

SELECT *
FROM school.student
GO




CREATE SCHEMA Measurements;
GO
CREATE TABLE Measurements.WeatherReading
(
    WeatherReadingId int NOT NULL IDENTITY
          CONSTRAINT PKWeatherReading PRIMARY KEY,
    ReadingTime   datetime2(3) NOT NULL
          CONSTRAINT AKMeasurements_WeatherReading_Date UNIQUE,
    Temperature     float NOT NULL
          CONSTRAINT chkMeasurements_WeatherReading_Temperature
                      CHECK(Temperature between -80 and 150)
                      --raised from last edition for global warming
);
GO

INSERT  into Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01);
GO

CREATE TABLE Measurements.WeatherReading_exception
(
    WeatherReadingId  int NOT NULL IDENTITY
          CONSTRAINT PKMeasurements_WeatherReading_exception PRIMARY KEY,
    ReadingTime       datetime2(3) NOT NULL,
    Temperature       float NOT NULL
);

GO
CREATE TRIGGER Measurements.WeatherReading$InsteadOfInsertTrigger
ON Measurements.WeatherReading
INSTEAD OF INSERT AS
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
           @rowsAffected int = (select count(*) from inserted)
   --           @rowsAffected int = (select count(*) from deleted)

   BEGIN TRY
          --[validation section]
          --[modification section]

          --<perform action>

           --BAD data
          INSERT Measurements.WeatherReading_exception
                                     (ReadingTime, Temperature)
          SELECT ReadingTime, Temperature
          FROM   inserted
          WHERE  NOT(Temperature between -80 and 120);

           --GOOD data
          INSERT Measurements.WeatherReading (ReadingTime, Temperature)
          SELECT ReadingTime, Temperature
          FROM   inserted
          WHERE  (Temperature between -80 and 120);
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH
END
GO

INSERT  INTO Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01);

SELECT *
FROM Measurements.WeatherReading;
GO

SELECT *
FROM   Measurements.WeatherReading_exception;
GO


CREATE SCHEMA System;
go
CREATE TABLE System.Version
(
    DatabaseVersion varchar(10) NOT NULL
);
INSERT  into System.Version (DatabaseVersion)
VALUES ('1.0.12');
GO

CREATE TRIGGER System.Version$InsteadOfInsertUpdateDeleteTrigger
ON System.Version
INSTEAD OF INSERT, UPDATE, DELETE AS
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
           @rowsAffected int = (select count(*) from inserted)

   IF @rowsAffected = 0 SET @rowsAffected = (select count(*) from deleted)

   --no need to complain if no rows affected
   IF @rowsAffected = 0 RETURN;

   --No error handling necessary, just the message.
   --We just put the kibosh on the action.
   THROW 50000, 'The System.Version table may not be modified in production', 16;
END;
GO

UPDATE system.version
SET    DatabaseVersion = '1.1.1';
GO


SELECT *
FROM   System.Version;
GO

ALTER TABLE system.version
    DISABLE TRIGGER version$InsteadOfInsertUpdateDeleteTrigger;
GO

UPDATE system.version
SET    DatabaseVersion = '1.1.1';
GO

SELECT *
FROM   System.Version;
GO

ALTER TABLE system.version
    ENABLE TRIGGER version$InsteadOfInsertUpdateDeleteTrigger;
GO



CREATE SCHEMA alt;
GO
CREATE TABLE alt.errorHandlingTest
(
    errorHandlingTestId   int NOT NULL CONSTRAINT PKerrorHandlingTest PRIMARY KEY,
    CONSTRAINT chkAlt_errorHandlingTest_errorHandlingTestId_greaterThanZero
           CHECK (errorHandlingTestId > 0)
);
GO


CREATE TRIGGER alt.errorHandlingTest$afterInsertTrigger
ON alt.errorHandlingTest
AFTER INSERT
AS
    BEGIN TRY
          THROW 50000, 'Test Error',16;
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
		        ROLLBACK TRANSACTION;
         THROW; 
    END CATCH
GO



--NO Transaction, Constraint Error
INSERT alt.errorHandlingTest
VALUES (-1);
SELECT 'continues';
GO


INSERT alt.errorHandlingTest
VALUES (1);
SELECT 'continues';
GO

BEGIN TRY
    BEGIN TRANSACTION
    INSERT alt.errorHandlingTest
    VALUES (-1);
    COMMIT
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;
    IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
GO


BEGIN TRANSACTION
   BEGIN TRY
        INSERT alt.errorHandlingTest
        VALUES (1);
       COMMIT TRANSACTION;
   END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;
    IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
GO

ALTER TRIGGER alt.errorHandlingTest$afterInsertTrigger
ON alt.errorHandlingTest
AFTER INSERT
AS
    BEGIN TRY
          THROW 50000, 'Test Error',16;
    END TRY
    BEGIN CATCH
         --Commented out for test purposes
         --IF @@TRANCOUNT > 0
         --    ROLLBACK TRANSACTION;

         THROW;
    END CATCH
GO

BEGIN TRY
    BEGIN TRANSACTION
    INSERT alt.errorHandlingTest
    VALUES (1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage;
     IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;
END CATCH
GO

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @errorMessage nvarchar(4000) = 'Error inserting data into alt.errorHandlingTest';
    INSERT alt.errorHandlingTest
    VALUES (-1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    --I also add in the stored procedure or trigger where the error
    --occurred also when in a coded object
    SET @errorMessage = Coalesce(@errorMessage,'') +
          ' ( System Error: ' + CAST(ERROR_NUMBER() as varchar(10)) +
          ':' + ERROR_MESSAGE() + ': Line Number:' +
          CAST(ERROR_LINE() as varchar(10)) + ')';
        THROW 50000,@errorMessage,16
END CATCH
GO

