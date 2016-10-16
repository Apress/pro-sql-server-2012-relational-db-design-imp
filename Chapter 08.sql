Create database Chapter8;
GO
USE Chapter8;
GO


CREATE SCHEMA HumanResources;
GO
CREATE TABLE HumanResources.employee
(
    EmployeeId int NOT NULL identity(1,1) constraint PKalt_employee primary key,
    EmployeeNumber char(5) NOT NULL
           CONSTRAINT AKalt_employee_employeeNummer UNIQUE,
    --skipping other columns you would likely have
    InsurancePolicyNumber char(10) NULL
);

Go

--Filtered Alternate Key (AKF)
CREATE UNIQUE INDEX AKFAccount_Contact_PrimaryContact ON
                                    HumanResources.employee(InsurancePolicyNumber)
WHERE InsurancePolicyNumber IS NOT NULL;
GO



INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002','1111111111');

GO
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0003','2222222222'),
       ('A0004',NULL),
       ('A0005',NULL);

GO
SELECT *
FROM   HumanResources.Employee;
GO



CREATE SCHEMA Account;
GO
CREATE TABLE Account.Contact
(
    ContactId   varchar(10) not null,
    AccountNumber   char(5) not null, --would be FK in full example
    PrimaryContactFlag bit not null,
    CONSTRAINT PKalt_accountContact
        PRIMARY KEY(ContactId, AccountNumber)
);

GO
CREATE UNIQUE INDEX
    AKFAccount_Contact_PrimaryContact
            ON Account.Contact(AccountNumber)
            WHERE PrimaryContactFlag = 1;

GO

INSERT INTO Account.Contact
SELECT 'bob','11111',1;
GO
INSERT INTO Account.Contact
SELECT 'fred','11111',1;

GO
BEGIN TRANSACTION;

UPDATE Account.Contact
SET primaryContactFlag = 0
WHERE  accountNumber = '11111';

INSERT Account.Contact
SELECT 'fred','11111', 1;

COMMIT TRANSACTION;

GO

DROP INDEX AKFAccount_Contact_PrimaryContact ON
                                    HumanResources.employee
GO
CREATE VIEW HumanResources.Employee_InsurancePolicyNumberUniqueness
WITH SCHEMABINDING
AS
SELECT InsurancePolicyNumber
FROM HumanResources.Employee
WHERE InsurancePolicyNumber IS NOT NULL;
GO

CREATE UNIQUE CLUSTERED INDEX
AKHumanResources_Employee_InsurancePolicyNumberUniqueness
ON HumanResources.Employee_InsurancePolicyNumberUniqueness(InsurancePolicyNumber);
GO
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0006','1111111111');
GO


CREATE SCHEMA Lego;
GO
CREATE TABLE Lego.Build
(
	BuildId int NOT NULL CONSTRAINT PKLegoBuild PRIMARY KEY,
	Name	varchar(30) NOT NULL CONSTRAINT AKLegoBuild_Name UNIQUE,
	LegoCode varchar(5) NULL, --five character set number
	InstructionsURL varchar(255) NULL --where you can get the PDF of the instructions
);
GO


CREATE TABLE Lego.BuildInstance
(
	BuildInstanceId Int CONSTRAINT PKLegoBuildInstance PRIMARY KEY ,
	BuildId	Int NOT NULL CONSTRAINT FKLegoBuildInstance$isAVersionOf$LegoBuild 
	                REFERENCES Lego.Build (BuildId),
	BuildInstanceName varchar(30) NOT NULL, --brief description of item 
	Notes varchar(1000)  NULL, --longform notes. These could describe modifications 
                                   --for the instance of the model
	CONSTRAINT AKLegoBuildInstance UNIQUE(BuildId, BuildInstanceName)
);

GO

CREATE TABLE Lego.Piece
(
	PieceId	int constraint PKLegoPiece PRIMARY KEY,
	Type    varchar(15) NOT NULL,
	Name    varchar(30) NOT NULL,
	Color   varchar(20) NULL,
	Width int NULL,
	Length int NULL,
	Height int NULL,
	LegoInventoryNumber int NULL,
	OwnedCount int NOT NULL,
        CONSTRAINT AKLego_Piece_Definition UNIQUE (Type,Name,Color,Width,Length,Height),
        CONSTRAINT AKLego_Piece_LegoInventoryNumber UNIQUE (LegoInventoryNumber)
);

GO

CREATE TABLE Lego.BuildInstancePiece
(
	BuildInstanceId int NOT NULL,
	PieceId int NOT NULL,
	AssignedCount int NOT NULL,
	CONSTRAINT PKLegoBuildInstancePiece PRIMARY KEY (BuildInstanceId, PieceId)
);

GO
INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (1,'Small Car','3177',
           'http://cache.lego.com/bigdownloads/buildinginstructions/4584500.pdf');


Go

INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (1,1,'Small Car for Book',NULL);

GO

INSERT Lego.Piece (PieceId, Type, Name, Color, Width, Length, Height, 
                   LegoInventoryNumber, OwnedCount)
VALUES  (1, 'Brick','Basic Brick','White',1,3,1,'362201',20),
	   (2, 'Slope','Slope','White',1,1,1,'4504369',2),
	   (3, 'Tile','Groved Tile','White',1,2,NULL,'306901',10),
	   (4, 'Plate','Plate','White',2,2,NULL,'302201',20),
	   (5, 'Plate','Plate','White',1,4,NULL,'371001',10),
	   (6, 'Plate','Plate','White',2,4,NULL,'302001',1),
	   (7, 'Bracket','1x2 Bracket with 2x2','White',2,1,2,'4277926',2),
	   (8, 'Mudguard','Vehicle Mudguard','White',2,4,NULL,'4289272',1),
	   (9, 'Door','Right Door','White',1,3,1,'4537987',1),
	   (10,'Door','Left Door','White',1,3,1,'45376377',1),
	   (11,'Panel','Panel','White',1,2,1,'486501',1),
	   (12,'Minifig Part','Minifig Torso , Sweatshirt','White',NULL,NULL,
                NULL,'4570026',1),
	   (13,'Steering Wheel','Steering Wheel','Blue',1,2,NULL,'9566',1),
	   (14,'Minifig Part','Minifig Head, Male Brown Eyes','Yellow',NULL, NULL, 
                NULL,'4570043',1),
	   (15,'Slope','Slope','Black',2,1,2,'4515373',2),
	   (16,'Mudguard','Vehicle Mudgard','Black',2,4,NULL,'4195378',1),
	   (17,'Tire','Vehicle Tire,Smooth','Black',NULL,NULL,NULL,'4508215',4),
	   (18,'Vehicle Base','Vehicle Base','Black',4,7,2,'244126',1),
	   (19,'Wedge','Wedge (Vehicle Roof)','Black',1,4,4,'4191191',1),
	   (20,'Plate','Plate','Lime Green',1,2,NULL,'302328',4),
	   (21,'Minifig Part','Minifig Legs','Lime Green',NULL,NULL,NULL,'74040',1),
	   (22,'Round Plate','Round Plate','Clear',1,1,NULL,'3005740',2),
	   (23,'Plate','Plate','Transparent Red',1,2,NULL,'4201019',1),
	   (24,'Briefcase','Briefcase','Reddish Brown',NULL,NULL,NULL,'4211235', 1),
	   (25,'Wheel','Wheel','Light Bluish Gray',NULL,NULL,NULL,'4211765',4),
	   (26,'Tile','Grilled Tile','Dark Bluish Gray',1,2,NULL,'4210631', 1),
	   (27,'Minifig Part','Brown Minifig Hair','Dark Brown',NULL,NULL,NULL,
               '4535553', 1),
	   (28,'Windshield','Windshield','Transparent Black',3,4,1,'4496442',1),
	   --and a few extra pieces to make the queries more interesting
	   (29,'Baseplate','Baseplate','Green',16,24,NULL,'3334',4),
	   (30,'Brick','Basic Brick','White',4,6,NULL,'2356',10 );


GO

INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (1,1,2),(1,2,2),(1,3,1),(1,4,2),(1,5,1),(1,6,1),(1,7,2),(1,8,1),(1,9,1),
       (1,10,1),(1,11,1),(1,12,1),(1,13,1),(1,14,1),(1,15,2),(1,16,1),(1,17,4),
       (1,18,1),(1,19,1),(1,20,4),(1,21,1),(1,22,2),(1,23,1),(1,24,1),(1,25,4),
       (1,26,1),(1,27,1),(1,28,1);

	    
GO


INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (2,'Brick Triangle',NULL,NULL);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (2,2,'Brick Triangle For Book','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (2,1,3);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (3,2,'Brick Triangle For Book2','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, AssignedCount)
VALUES (3,1,3);

GO

SELECT COUNT(*) AS PieceCount ,SUM(OwnedCount) as InventoryCount
FROM  Lego.Piece;

GO

SELECT Type, COUNT(*) as TypeCount, SUM(OwnedCount) as InventoryCount
FROM  Lego.Piece
GROUP BY Type;

GO

SELECT CASE WHEN GROUPING(Piece.Type) = 1 THEN '--Total--' ELSE Piece.Type END AS PieceType,
		Piece.Color,Piece.Height, Piece.Width, Piece.Length,
	   SUM(BuildInstancePiece.AssignedCount) as AssignedCount
FROM   Lego.Build
		 JOIN Lego.BuildInstance	
			oN Build.BuildId = BuildInstance.BuildId
		 JOIN Lego.BuildInstancePiece
			on BuildInstance.BuildInstanceId = 
                                    BuildInstancePiece.BuildInstanceId
		 JOIN Lego.Piece
			ON BuildInstancePiece.PieceId = Piece.PieceId
WHERE  Build.Name = 'Small Car'
       and  BuildInstanceName = 'Small Car for Book'
GROUP BY GROUPING SETS((Piece.Type,Piece.Color, Piece.Height, Piece.Width, Piece.Length),
                       ());

GO


;WITH AssignedPieceCount
AS (
SELECT PieceId, SUM(AssignedCount) as TotalAssignedCount
FROM   Lego.BuildInstancePiece
GROUP  BY PieceId )

SELECT Type, Name,  Width, Length,Height, 
       Piece.OwnedCount - Coalesce(TotalAssignedCount,0) as AvailableCount
FROM   Lego.Piece
		 LEFT OUTER JOIN AssignedPieceCount
			on Piece.PieceId =  AssignedPieceCount.PieceId
WHERE Piece.OwnedCount - Coalesce(TotalAssignedCount,0) > 0; 

GO

--============================================
--============================================
CREATE SCHEMA office;
GO
CREATE TABLE office.doctor
(
		doctorId	int NOT NULL CONSTRAINT PKOfficeDoctor PRIMARY KEY,
		doctorNumber char(5) NOT NULL CONSTRAINT AKOfficeDoctor_doctorNumber UNIQUE
);
CREATE TABLE office.appointment
(
	appointmentId	int NOT NULL CONSTRAINT PKOfficeAppointment PRIMARY KEY,
        --real situation would include room, patient, etc, 
	doctorId	int NOT NULL,
	startTime	datetime2(0) NOT NULL, --precision to the second
	endTime		datetime2(0) NOT NULL,
	CONSTRAINT AKOfficeAppointment_DoctorStartTime UNIQUE (doctorId,startTime),
	CONSTRAINT AKOfficeAppointment_StartBeforeEnd CHECK (startTime <= endTime)
);

GO
INSERT INTO office.doctor (doctorId, doctorNumber)
VALUES (1,'00001'),(2,'00002');
INSERT INTO office.appointment
VALUES (1,1,'20110712 14:00','20110712 14:59:59'),
	   (2,1,'20110712 15:00','20110712 16:59:59'),
	   (3,2,'20110712 8:00','20110712 11:59:59'),
	   (4,2,'20110712 13:00','20110712 17:59:59'),
	   (5,2,'20110712 14:00','20110712 14:59:59'); --offensive item for demo, conflicts                
                                                       --with 4

GO

SELECT appointment.appointmentId,
       Acheck.appointmentId as conflictingAppointmentId
FROM   office.appointment
          JOIN office.appointment as ACheck
		ON appointment.doctorId = ACheck.doctorId
	/*1*/	   and appointment.appointmentId <> ACheck.appointmentId
	/*2*/	  and (Appointment.startTime between Acheck.startTime and Acheck.endTime  
	/*3*/	        or Appointment.endTime between Acheck.startTime and Acheck.endTime
	/*4*/	        or (appointment.startTime < Acheck.startTime 
                            and appointment.endTime > Acheck.endTime));

GO
DELETE FROM office.appointment where AppointmentId = 5;
GO
CREATE TRIGGER office.appointment$insertAndUpdateTrigger
ON office.appointment
AFTER UPDATE, INSERT AS
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
         --[validation section]
	IF UPDATE(startTime) or UPDATE(endTime) or UPDATE(doctorId)
	   BEGIN
	   IF EXISTS ( SELECT *
                       FROM   office.appointment
                                join office.appointment as ACheck
                                    on appointment.doctorId = ACheck.doctorId
                                       and appointment.appointmentId <> ACheck.appointmentId
                                       and (Appointment.startTime between Acheck.startTime 
                                                                        and Acheck.endTime
                                            or Appointment.endTime between Acheck.startTime 
                                                                        and Acheck.endTime
                                            or (appointment.startTime < Acheck.startTime 
                                                 and appointment.endTime > Acheck.endTime))
			      WHERE  EXISTS (SELECT *									             FROM   inserted
					     WHERE  inserted.doctorId = Acheck.doctorId))
	           BEGIN
			 IF @rowsAffected = 1
			         SELECT @msg = 'Appointment for doctor ' + doctorNumber + 
                                                ' overlapped existing appointment'
                                 FROM   inserted
					   JOIN office.doctor
  				  	       on inserted.doctorId = doctor.doctorId;
  				ELSE
                                    SELECT @msg = 'One of the rows caused an overlapping ' +              
                                                   'appointment time for a doctor';
		        THROW 50000,@msg,16;

		   END
         END
          --[modification section]
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

   END CATCH
END

GO

SELECT *
FROM   office.appointment;

GO


--duplicate time
INSERT INTO office.appointment
VALUES (5,1,'20110712 14:00','20110712 14:59:59');

GO

--overlapping range
INSERT INTO office.appointment
VALUES (5,1,'20110712 14:30','20110712 14:40:59');

GO

--overlapping range
INSERT INTO office.appointment
VALUES (5,1,'20110712 11:30','20110712 14:59:59');

GO

INSERT into office.appointment
VALUES (5,1,'20110712 11:30','20110712 14:59:59'),
       (6,2,'20110713 10:00','20110713 10:59:59')


GO

INSERT INTO office.appointment
VALUES (5,1,'20110712 10:00','20110712 11:59:59'),
       (6,2,'20110713 10:00','20110713 10:59:59');


GO
UPDATE office.appointment
SET    startTime = '20110712 15:30',
       endTime = '20110712 15:59:59'
WHERE  appointmentId = 1; 

GO

--=======================================================
--=======================================================

CREATE SCHEMA corporate;
GO
CREATE TABLE corporate.company
(
    companyId   int NOT NULL CONSTRAINT PKcompany primary key,
    name        varchar(20) NOT NULL CONSTRAINT AKcompany_name UNIQUE,
    parentCompanyId int NULL
      CONSTRAINT company$isParentOf$company REFERENCES corporate.company(companyId)
);  

GO
INSERT INTO corporate.company (companyId, name, parentCompanyId)
VALUES (1, 'Company HQ', NULL),
       (2, 'Maine HQ',1),              (3, 'Tennessee HQ',1),
       (4, 'Nashville Branch',3),      (5, 'Knoxville Branch',3),
       (6, 'Memphis Branch',3),        (7, 'Portland Branch',2),
       (8, 'Camden Branch',2);

GO
SELECT *
FROM    corporate.company;

GO

--getting the children of a row (or ancestors with slight mod to query)
DECLARE @companyId int = 1;

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company
              INNER JOIN companyHierarchy
                --use to get children
                on company.parentCompanyId= companyHierarchy.companyID
                --use to get parents
                --on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy ;
GO



--getting the children of a row (or ancestors with slight mod to query)
DECLARE @companyId int = 3;

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company as company
              INNER JOIN companyHierarchy
                --use to get children
                on company.parentCompanyId= companyHierarchy.companyID
                --use to get parents
                --on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company as company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy;

GO

CREATE SCHEMA Parts;
GO
CREATE TABLE Parts.Part
(
	PartId	int	NOT NULL CONSTRAINT PKPartsPart PRIMARY KEY,
	PartNumber char(5) NOT NULL CONSTRAINT AKPartsPart UNIQUE,
	Name    varchar(20) NULL
);

GO
INSERT INTO Parts.Part (PartId, PartNumber,Name)
VALUES (1,'00001','Screw'),(2,'00002','Piece of Wood'),
       (3,'00003','Tape'),(4,'00004','Screw and Tape'),
       (5,'00005','Wood with Tape');


GO
CREATE TABLE Parts.Assembly
(
       PartId	int NOT NULL
            CONSTRAINT FKPartsAssembly$contains$PartsPart
                              REFERENCES Parts.Part(PartId),
       ContainsPartId	int NOT NULL
            CONSTRAINT FKPartsAssembly$isContainedBy$PartsPart
                              REFERENCES Parts.Part(PartId),
            CONSTRAINT PKPartsAssembly PRIMARY KEY (PartId, ContainsPartId),
);

GO

INSERT INTO PARTS.Assembly(PartId,ContainsPartId)
VALUES (4,1),(4,3);
GO
INSERT INTO Parts.Assembly(PartId,ContainsPartId)
VALUES (5,1),(4,2);
GO

CREATE TABLE corporate.company2
(
    companyOrgNode hierarchyId NOT NULL 
                 CONSTRAINT AKcompany UNIQUE,
    companyId   int NOT NULL CONSTRAINT PKcompany2 primary key,
    name        varchar(20) NOT NULL CONSTRAINT AKcompany2_name UNIQUE,
);   

GO
INSERT corporate.company2 (companyOrgNode, CompanyId, Name)
VALUES (hierarchyid::GetRoot(), 1, 'Company HQ');


GO
CREATE PROCEDURE corporate.company2$insert(@companyId int, @parentCompanyId int, 
                                          @name varchar(20)) 
AS 
BEGIN
   SET NOCOUNT ON
   --the last child will be used when generating the next node, 
   --and the parent is used to set the parent in the insert
   DECLARE  @lastChildofParentOrgNode hierarchyid,
            @parentCompanyOrgNode hierarchyid; 
   IF @parentCompanyId is not null
     BEGIN
        SET @parentCompanyOrgNode = 
                            (  SELECT companyOrgNode 
                               FROM   corporate.company2
                               WHERE  companyID = @parentCompanyId)
	 IF  @parentCompanyOrgNode is null
           BEGIN
                THROW 50000, 'Invalid parentCompanyId passed in',16 
	         RETURN -100;
            END
    END
   
   BEGIN TRANSACTION;

      --get the last child of the parent you passed in if one exists
      SELECT @lastChildofParentOrgNode = max(companyOrgNode) 
      FROM corporate.company2 (UPDLOCK) --compatibile with shared, but blocks
                                       --other connections trying to get an UPDLOCK 
      WHERE companyOrgNode.GetAncestor(1) =@parentCompanyOrgNode ;

      --getDecendant will give you the next node that is greater than 
      --the one passed in.  Since the value was the max in the table, the 
      --getDescendant Method returns the next one
      INSERT corporate.company2 (companyOrgNode, companyId, name)
             --the coalesce puts the row as a NULL this will be a root node
             --invalid parentCompanyId values were tossed out earlier
      SELECT COALESCE(@parentCompanyOrgNode.GetDescendant(
                   @lastChildofParentOrgNode, NULL),hierarchyid::GetRoot())
                  ,@companyId, @name;
   COMMIT;
END 

GO
--exec corporate.company2$insert @companyId = 1, @parentCompanyId = NULL,
--                               @name = 'Company HQ'; --already created
exec corporate.company2$insert @companyId = 2, @parentCompanyId = 1,
                                 @name = 'Maine HQ';
exec corporate.company2$insert @companyId = 3, @parentCompanyId = 1, 
                                 @name = 'Tennessee HQ';
exec corporate.company2$insert @companyId = 4, @parentCompanyId = 3, 
                                 @name = 'Knoxville Branch';
exec corporate.company2$insert @companyId = 5, @parentCompanyId = 3, 
                                 @name = 'Memphis Branch';
exec corporate.company2$insert @companyId = 6, @parentCompanyId = 2, 
                                 @name = 'Portland Branch';
exec corporate.company2$insert @companyId = 7, @parentCompanyId = 2, 
                                 @name = 'Camden Branch';

GO
SELECT  companyOrgNode, companyId,   name
FROM    corporate.company2;

GO
SELECT companyId, companyOrgNode.GetLevel() as level,
       name, companyOrgNode.ToString() as hierarchy 
FROM   corporate.company2;

GO
DECLARE @companyId int = 3;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.company2 AS Target
	       JOIN corporate.company2 AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and Target.companyOrgNode.IsDescendantOf
                                                 (SearchFor.companyOrgNode) = 1;


GO
DECLARE @companyId int = 3;
SELECT Target.companyId, Target.name, Target.companyOrgNode.ToString() as hierarchy
FROM   corporate.company2 AS Target
	       JOIN corporate.company2 AS SearchFor
		       ON SearchFor.companyId = @companyId
                          and SearchFor.companyOrgNode.IsDescendantOf
                                                 (Target.companyOrgNode) = 1;

GO
--===============================================
--===============================================

CREATE  DATABASE FileStorageDemo; --uses basic defaults from model databases
GO
USE FileStorageDemo;
GO

--will cover filegroups more in the chapter 10 on structures
ALTER DATABASE FileStorageDemo ADD
	FILEGROUP FilestreamData CONTAINS FILESTREAM;

GO
ALTER DATABASE FileStorageDemo ADD FILE (
       NAME = FilestreamDataFile1,
       FILENAME = 'd:\sql\filestream') --directory cannot yet exist
TO FILEGROUP FilestreamData;
GO

CREATE TABLE TestSimpleFileStream
(
        TestSimpleFilestreamId INT NOT NULL 
                      CONSTRAINT PKTestSimpleFileStream PRIMARY KEY,
        FileStreamColumn VARBINARY(MAX) FILESTREAM NULL,
         RowGuid uniqueidentifier NOT NULL ROWGUIDCOL DEFAULT (NewId()) UNIQUE
)       FILESTREAM_ON FilestreamData; --optional, goes to default otherwise
GO

INSERT INTO TestSimpleFileStream(TestSimpleFilestreamId,FileStreamColumn)
SELECT 1, CAST('This is an exciting example' as varbinary(max));
GO

SELECT TestSimpleFilestreamId,FileStreamColumn,CAST(FileStreamColumn as varchar(40))
FROM   TestSimpleFilestream;

Go
EXEC sp_configure filestream_access_level, 2;
RECONFIGURE;
GO
ALTER database FileStorageDemo
	SET FILESTREAM (NON_TRANSACTED_ACCESS = FULL, 
                         DIRECTORY_NAME = N'ProSQLServer2012DBDesign');

GO
CREATE TABLE dbo.FileTableTest AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
	FILETABLE_COLLATE_FILENAME = database_default
	);

GO
INSERT INTO FiletableTest(name, is_directory) 
VALUES ( 'Project 1', 1);

GO
SELECT stream_id, file_stream, name
FROM   FileTableTest
WHERE  name = 'Project 1';

GO
INSERT INTO FiletableTest(name, is_directory, file_stream) 
VALUES ( 'Test.Txt', 0, cast('This is some text' as varbinary(max)));

GO
UPDATE FiletableTest
SET    path_locator = path_locator.GetReparentedValue( path_locator.GetAncestor(1),
       (SELECT path_locator FROM FiletableTest 
	    WHERE name = 'Project 1' 
		  AND parent_path_locator is NULL
		  AND is_directory = 1))
WHERE name = 'Test.Txt';

GO
SELECT  CONCAT(FileTableRootPath(),
		            file_stream.GetFileNamespacePath()) AS FilePath
FROM	dbo.FileTableTest
WHERE name = 'Project 1' 
		  AND parent_path_locator is NULL
		  AND is_directory = 1;

GO
--=======================================================
--=======================================================
Use Chapter8
GO

CREATE SCHEMA Inventory;
GO
CREATE TABLE Inventory.Item
(
	ItemId	int NOT NULL IDENTITY CONSTRAINT PKInventoryItem PRIMARY KEY,
	Name    varchar(30) NOT NULL CONSTRAINT AKInventoryItemName UNIQUE,
	Type    varchar(15) NOT NULL,
	Color	varchar(15) NOT NULL,
	Description varchar(100) NOT NULL,
	ApproximateValue  numeric(12,2) NULL,
	ReceiptImage   varbinary(max) NULL,
	PhotographicImage varbinary(max) NULL
);

GO
INSERT INTO Inventory.Item
VALUES ('Den Couch','Furniture','Blue','Blue plaid couch, seats 4',450.00,0x001,0x001),
       ('Den Ottoman','Furniture','Blue','Blue plaid ottoman that goes with couch',  
         150.00,0x001,0x001),
       ('40 Inch Sorny TV','Electronics','Black',
        '40 Inch Sorny TV, Model R2D12, Serial Number XD49292',
	 800,0x001,0x001),
        ('29 Inch JQC TV','Electronics','Black','29 Inch JQC CRTVX29 TV',800,0x001,0x001),
	('Mom''s Pearl Necklace','Jewelery','White',
         'Appraised for $1300 in June of 2003. 30 inch necklace, was Mom''s',
	 1300,0x001,0x001);

GO
SELECT Name, Type, Description
FROM   Inventory.Item;

GO
CREATE TABLE Inventory.JeweleryItem
(
	ItemId	int	CONSTRAINT PKInventoryJewleryItem PRIMARY KEY
	            CONSTRAINT FKInventoryJewleryItem$Extends$InventoryItem
				           REFERENCES Inventory.Item(ItemId),
	QualityLevel   varchar(10) NOT NULL,
	AppraiserName  varchar(100) NULL,
	AppraisalValue numeric(12,2) NULL,
	AppraisalYear  char(4) NULL

);

GO
CREATE TABLE Inventory.ElectronicItem
(
	ItemId	int	CONSTRAINT PKInventoryElectronicItem PRIMARY KEY
	            CONSTRAINT FKInventoryElectronicItem$Extends$InventoryItem
				           REFERENCES Inventory.Item(ItemId),
	BrandName  varchar(20) NOT NULL,
	ModelNumber varchar(20) NOT NULL,
	SerialNumber varchar(20) NULL
);

GO


UPDATE Inventory.Item
SET    Description = '40 Inch TV' 
WHERE  Name = '40 Inch Sorny TV';
GO
INSERT INTO Inventory.ElectronicItem (ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'Sorny','R2D12','XD49393'
FROM   Inventory.Item
WHERE  Name = '40 Inch Sorny TV';
GO
UPDATE Inventory.Item
SET    Description = '29 Inch TV' 
WHERE  Name = '29 Inch JQC TV';
GO
INSERT INTO Inventory.ElectronicItem(ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'JVC','CRTVX29',NULL
FROM   Inventory.Item
WHERE  Name = '29 Inch JQC TV';
GO


UPDATE Inventory.Item
SET    Description = '30 Inch Pearl Neclace' 
WHERE  Name = 'Mom''s Pearl Necklace';
GO

INSERT INTO Inventory.JeweleryItem (ItemId, QualityLevel, AppraiserName, AppraisalValue,AppraisalYear )
SELECT ItemId, 'Fine','Joey Appraiser',1300,'2003'
FROM   Inventory.Item
WHERE  Name = 'Mom''s Pearl Necklace';
GO

SELECT Name, Type, Description
FROM   Inventory.Item;
GO

SELECT Item.Name, ElectronicItem.BrandName, ElectronicItem.ModelNumber, ElectronicItem.SerialNumber
FROM   Inventory.ElectronicItem
         JOIN Inventory.Item
		     ON Item.ItemId = ElectronicItem.ItemId;
GO

SELECT Name, Description, 
       CASE Type
	  WHEN 'Electronics'
	    THEN 'Brand:' + COALESCE(BrandName,'_______') +
	         ' Model:' + COALESCE(ModelNumber,'________')  + 
	         ' SerialNumber:' + COALESCE(SerialNumber,'_______')
	  WHEN 'Jewelery'
            THEN 'QualityLevel:' + QualityLevel +
		 ' Appraiser:' + COALESCE(AppraiserName,'_______') +
		 ' AppraisalValue:' +COALESCE(Cast(AppraisalValue as varchar(20)),'_______')   
                 +' AppraisalYear:' + COALESCE(AppraisalYear,'____') 
  	    ELSE '' END as ExtendedDescription
FROM   Inventory.Item --outer joins because every item will only have one of these if any
           LEFT OUTER JOIN Inventory.ElectronicItem
		        ON Item.ItemId = ElectronicItem.ItemId
	       LEFT OUTER JOIN Inventory.JeweleryItem
	           	ON Item.ItemId = JeweleryItem.ItemId;

GO
--==========================================================
--==========================================================
CREATE SCHEMA Hardware;
GO
CREATE TABLE Hardware.Equipment
(
    EquipmentId int NOT NULL
          CONSTRAINT PKHardwareEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKHardwareEquipment UNIQUE,
    EquipmentType varchar(10),
	
);
GO
INSERT INTO Hardware.Equipment
VALUES (1,'CLAWHAMMER','Hammer'),
       (2,'HANDSAW','Saw'),
       (3,'POWERDRILL','PowerTool');
GO

/*
CREATE TABLE Hardware.Equipment_AltDesign
(
    EquipmentId int NOT NULL
          CONSTRAINT PKHardwareEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKHardwareEquipment UNIQUE,
    EquipmentType varchar(10),
	UserDefined1  sql_variant,
	UserDefined2  sql_variant,
	UserDefined3  sql_variant,
	UserDefined4  sql_variant,
	UserDefined5  sql_variant,
	UserDefined6  sql_variant
);
*/

CREATE TABLE Hardware.EquipmentPropertyType
(
    EquipmentPropertyTypeId int NOT NULL
        CONSTRAINT PKHardwareEquipmentPropertyType PRIMARY KEY,
    Name varchar(15) NOT NULL
        CONSTRAINT AKHardwareEquipmentPropertyType UNIQUE,
    TreatAsDatatype sysname NOT NULL
);

INSERT INTO Hardware.EquipmentPropertyType
VALUES(1,'Width','numeric(10,2)'),
      (2,'Length','numeric(10,2)'),
      (3,'HammerHeadStyle','varchar(30)');
GO

CREATE TABLE Hardware.EquipmentProperty
(
    EquipmentId int NOT NULL
      CONSTRAINT FKHardwareEquipment$hasExtendedPropertiesIn$HardwareEquipmentProperty
           REFERENCES Hardware.Equipment(EquipmentId),
    EquipmentPropertyTypeId int NOT NULL
      CONSTRAINT FKHardwareEquipmentPropertyTypeId$definesTypesFor$HardwareEquipmentProperty
           REFERENCES Hardware.EquipmentPropertyType(EquipmentPropertyTypeId),
    Value sql_variant NOT NULL,
    CONSTRAINT PKHardwareEquipmentProperty PRIMARY KEY
                     (EquipmentId, EquipmentPropertyTypeId)
);
GO

CREATE PROCEDURE Hardware.EquipmentProperty$Insert
(
    @EquipmentId int,
    @EquipmentPropertyName varchar(15),
    @Value sql_variant
)
AS
    SET NOCOUNT ON;
    DECLARE @entryTrancount int = @@trancount;

    BEGIN TRY
        DECLARE @EquipmentPropertyTypeId int,
                @TreatASDatatype sysname;

        SELECT @TreatASDatatype = TreatAsDatatype,
               @EquipmentPropertyTypeId = EquipmentPropertyTypeId
        FROM   Hardware.EquipmentPropertyType
        WHERE  EquipmentPropertyType.Name = @EquipmentPropertyName;

      BEGIN TRANSACTION;
        --insert the value
        INSERT INTO Hardware.EquipmentProperty(EquipmentId, EquipmentPropertyTypeId,
                    Value)
        VALUES (@EquipmentId, @EquipmentPropertyTypeId, @Value);


        --Then get that value from the table and cast it in a dynamic SQL
        -- call.  This will raise a trappable error if the type is incompatible
        DECLARE @validationQuery  varchar(max) =
              ' DECLARE @value sql_variant
                SELECT  @value = cast(value as ' + @TreatASDatatype + ')
                FROM    Hardware.EquipmentProperty
                WHERE   EquipmentId = ' + cast (@EquipmentId as varchar(10)) + '
                  and   EquipmentPropertyTypeId = ' +
                       cast(@EquipmentPropertyTypeId as varchar(10)) + ' ';

        EXECUTE (@validationQuery);
      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
             ROLLBACK TRANSACTION;

         DECLARE @ERRORmessage nvarchar(4000)
         SET @ERRORmessage = 'Error occurred in procedure ''' +
                  object_name(@@procid) + ''', Original Message: '''
                 + ERROR_MESSAGE() + '''';
      THROW 50000,@ERRORMessage,16;
      RETURN -100;

     END CATCH

GO
EXEC Hardware.EquipmentProperty$Insert 1,'Width','Claw'; --width is numeric(10,2)
GO

EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Width', @Value = 2;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Length',@Value = 8.4;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'HammerHeadStyle',@Value = 'Claw'
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Width',@Value = 1;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Length',@Value = 7;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Width',@Value = 6;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Length',@Value = 12.1;

GO
SELECT Equipment.EquipmentTag,Equipment.EquipmentType,
       EquipmentPropertyType.name, EquipmentProperty.Value
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            ON Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            ON EquipmentPropertyType.EquipmentPropertyTypeId =
                                   EquipmentProperty.EquipmentPropertyTypeId;

GO

SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.
SELECT  Equipment.EquipmentTag,Equipment.EquipmentType,
   MAX(CASE WHEN EquipmentPropertyType.name = 'HammerHeadStyle' THEN Value END)
                                                            AS 'HammerHeadStyle',
   MAX(CASE WHEN EquipmentPropertyType.name = 'Length'THEN Value END) AS Length,
   MAX(CASE WHEN EquipmentPropertyType.name = 'Width' THEN Value END) AS Width
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                                     EquipmentProperty.EquipmentPropertyTypeId
GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType;
SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.


GO
SET ANSI_WARNINGS OFF;
DECLARE @query varchar(8000);
SELECT  @query = 'select Equipment.EquipmentTag,Equipment.EquipmentType ' + (
                SELECT DISTINCT
                    ',MAX(CASE WHEN EquipmentPropertyType.name = ''' +
                       EquipmentPropertyType.name + ''' THEN cast(Value as ' +
                       EquipmentPropertyType.TreatAsDatatype + ') END) AS [' +
                       EquipmentPropertyType.name + ']' AS [text()]
                FROM
                    Hardware.EquipmentPropertyType
                FOR XML PATH('') ) + '
                FROM  Hardware.EquipmentProperty
                             JOIN Hardware.Equipment
                                on Equipment.EquipmentId =
                                     EquipmentProperty.EquipmentId
                             JOIN Hardware.EquipmentPropertyType
                                on EquipmentPropertyType.EquipmentPropertyTypeId
                                   = EquipmentProperty.EquipmentPropertyTypeId
          GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType  '
EXEC (@query);

GO

ALTER TABLE Hardware.Equipment
    ADD Length numeric(10,2) SPARSE NULL;

GO
CREATE PROCEDURE Hardware.Equipment$addProperty
(
    @propertyName   sysname, --the column to add
    @datatype       sysname, --the datatype as it appears in a column creation
    @sparselyPopulatedFlag bit = 1 --Add column as sparse or not
)
WITH EXECUTE AS SELF
AS
  --note: I did not include full error handling for clarity
  DECLARE @query nvarchar(max);

 --check for column existance
 IF NOT EXISTS (SELECT *
               FROM   sys.columns
               WHERE  name = @propertyName
                 AND  OBJECT_NAME(object_id) = 'Equipment'
                 AND  OBJECT_SCHEMA_NAME(object_id) = 'Hardware')
  BEGIN
    --build the ALTER statement, then execute it
     SET @query = 'ALTER TABLE Hardware.Equipment ADD ' + quotename(@propertyName) + ' '
                + @datatype
                + case when @sparselyPopulatedFlag = 1 then ' SPARSE ' end
                + ' NULL ';
     EXEC (@query);
  END
 ELSE
     THROW 50000, 'The property you are adding already exists',16;


GO
--EXEC Hardware.Equipment$addProperty 'Length','numeric(10,2)',1; -- added manually
EXEC Hardware.Equipment$addProperty 'Width','numeric(10,2)',1;
EXEC Hardware.Equipment$addProperty 'HammerHeadStyle','varchar(30)',1;

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;

GO
UPDATE Hardware.Equipment
SET    Length = 7.00,
       Width =  1.00
WHERE  EquipmentTag = 'HANDSAW';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;
GO
ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKHardwareEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');
GO
UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00,
       HammerHeadStyle = 'Wrong!'
WHERE  EquipmentTag = 'HANDSAW';

GO

UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    Length = 8.40,
       Width =  2.00,
       HammerHeadStyle = 'Claw'
WHERE  EquipmentTag = 'CLAWHAMMER';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle ,Length,Width
FROM   Hardware.Equipment;


GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle
       ,Length,Width
FROM   Hardware.Equipment;
GO
SELECT name, is_sparse
FROM   sys.columns
WHERE  OBJECT_NAME(object_id) = 'Equipment'

GO
ALTER TABLE Hardware.Equipment
    DROP CONSTRAINT CHKHardwareEquipment$HammerHeadStyle;
ALTER TABLE Hardware.Equipment
    DROP COLUMN HammerHeadStyle, Length, Width;
GO

ALTER TABLE Hardware.Equipment
  ADD SparseColumns xml column_set FOR ALL_SPARSE_COLUMNS;

GO
EXEC Hardware.equipment$addProperty 'Length','numeric(10,2)',1;
EXEC Hardware.equipment$addProperty 'Width','numeric(10,2)',1;
EXEC Hardware.equipment$addProperty 'HammerHeadStyle','varchar(30)',1;
GO


ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKHardwareEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');

GO

UPDATE Hardware.Equipment
SET    Length = 7,
       Width =  1
WHERE  EquipmentTag = 'HANDSAW';

GO

SELECT *
FROM   Hardware.Equipment;
GO

UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>12.10</Length><Width>6.00</Width>'
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>8.40</Length><Width>2.00</Width>
                        <HammerHeadStyle>Claw</HammerHeadStyle>'
WHERE  EquipmentTag = 'CLAWHAMMER';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle, Length, Width
FROM   Hardware.Equipment;
