-- PSBA is not a system of record
-- Deleted clients do not exist here
-- You may remove all PoU for a client if resources need to be freed but the client record is needed
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
    PlanOverrideExpDateUTC TIMESTAMP,
    AddonProfileOverride VARCHAR(64),
    AddonProfileOverrideExpDateUTC TIMESTAMP,
    CampaignProfile VARCHAR(64),
    CampaignExpDateUTC TIMESTAMP
);

CREATE UNIQUE INDEX ClientsExternalClientId_idx ON clients (ExternalClientId);
CREATE INDEX ClientsContractId_idx ON clients (ContractId);
CREATE INDEX ClientsPersonalId_idx ON clients (PersonalId);

-- Access port may be, typically, a NAS-Port
-- AccessId may be an CircuitId, or RemoteId, BNG group or BNG Address to be used in combination with NAS-Port
-- It is up to the radius algorithm to use the fields
-- Password mab be store in clear or with {algorithm}<value>
-- CheckType depends on the implementation. Used to define if the username must be
-- validated, among other possibilites
CREATE TABLE IF NOT EXISTS pou (
    PoUId INT AUTO_INCREMENT PRIMARY KEY,
    ClientId INT REFERENCES Clients(ClientId),
    AccessPort INT,
    AccessId VARCHAR(128),
    UserName VARCHAR(64),
    Passwd VARCHAR(128),
    IPv4Address VARCHAR(32),
    IPv4DelegatedPrefix VARCHAR(64),
    IPv6WANPrefix VARCHAR(64),
    AccessType INT,
    CheckType INT

);

CREATE INDEX PouClient_idx ON pou (ClientId);
CREATE INDEX PouAccessIdPort_idx ON pou (AccessId, AccessPort);
CREATE INDEX PoUUserName_idx ON pou (UserName);
CREATE INDEX PoUIPv4Address_idx ON pou (IPv4Address);

CREATE USER IF NOT EXISTS api_user PASSWORD 'mypassword';
GRANT SELECT, INSERT, DELETE ON clients TO api_user;

