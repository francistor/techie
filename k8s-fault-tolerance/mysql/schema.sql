DROP DATABASE IF EXISTS PSBA;
CREATE DATABASE PSBA;
USE PSBA;

-- PSBA is not a system of record
-- Deleted clients do not exist here
-- You may remove all PoU for a client if resources need to be freed but the client record is needed
-- Campaing management is performed externally. Here, only a mark stating whether the user should be redirected to the
-- captive portal is used (NotificationExpDate)
CREATE TABLE IF NOT EXISTS clients (
    ClientId INT AUTO_INCREMENT PRIMARY KEY,
    ExternalClientId VARCHAR(64) NOT NULL,
    ContractId VARCHAR(64),
    PersonalId VARCHAR(64),
    SecondaryId VARCHAR(64),
    ISP VARCHAR(32),
    BillingCycle INT,
    PlanName VARCHAR(32) NOT NULL,
    BlockingStatus INT NOT NULL,
    PlanOverride VARCHAR(64),
    PlanOverrideExpDate TIMESTAMP,
    AddonProfileOverride VARCHAR(64),
    AddonProfileOverrideExpDate TIMESTAMP,
    NotificationExpDate TIMESTAMP,    -- Client in a campaign will have a not null value
    Parameters JSON, -- Array of {"<parametername>": <parametervalue> [,"expDate": <expiraton date>]}
    Version INT Default 0
);


CREATE UNIQUE INDEX ClientsExternalClientId_idx ON clients (ExternalClientId);
CREATE INDEX ClientsContractId_idx ON clients (ContractId);
CREATE INDEX ClientsPersonalId_idx ON clients (PersonalId);

DELIMITER //
DROP PROCEDURE IF EXISTS populate //
CREATE PROCEDURE populate(IN entries INT)
BEGIN    
    DECLARE i INT unsigned;
    SET i = 0;
    DELETE FROM clients;
    WHILE i < entries DO
        SET i = i+1;
        insert into clients (ExternalClientId, ContractId, PersonalId, PlanName, BlockingStatus) values (CONCAT("External", i), CONCAT("Contract", i), CONCAT("Personal", i), CONCAT("Plan", i), 0);  
    END WHILE;
END // 
delimiter ;


