package com.indra.telco.psba;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

@Repository
public class PSBARepository {

    private static Logger logger = LoggerFactory.getLogger(PSBARepository.class);

    private final JdbcTemplate jdbc;

    public PSBARepository(JdbcTemplate jdbc){
        this.jdbc = jdbc;
    }

    public void createClient(Client client){
        String sql = "INSERT INTO clients (ExternalClientId, PlanName, BlockingStatus) VALUES (?, ?, ?)";

        jdbc.update(sql, client.getExternalClientId(), client.getPlanName(), client.getBlockingStatus());
    }

    public int createClientWithId(Client client){
        String sql = "INSERT INTO clients (ExternalClientId, PlanName, BlockingStatus) VALUES (?, ?, ?)";

        KeyHolder keyHolder = new GeneratedKeyHolder();
        int rowsAffected = jdbc.update(conn -> {
            PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, client.getExternalClientId());
            ps.setString(2, client.getPlanName());
            ps.setInt(3, client.getBlockingStatus());
            return ps;
        }, keyHolder);

        var key = keyHolder.getKey();
        if(key == null){
            logger.error("key was null " + rowsAffected);
            return 0; 
        } else return key.intValue();
    }

    public Optional<Client> findClientById(int clientId){

        String sql = "SELECT ClientId, ExternalClientId, ContractId, PersonalId, SecondaryId, ISP, BillingCycle, PlanName, BlockingStatus, PlanOverride, PlanOverrideExpDateUTC, AddonProfileOverride, AddonProfileOverrideExpDateUTC, CampaignProfile, CampaignExpDateUTC " +
        "FROM clients where ClientId = ?";

        RowMapper<Client> clientRowMapper = (r, i) -> {
            Client client = new Client();

            client.setClientId(r.getInt("ClientId"));
            client.setExternalClientId(r.getString("ExternalClientId"));
            client.setContractId((r.getString("ContractId")));
            client.setPersonalId(r.getString("PersonalId"));
            client.setSecondaryId(r.getString("SecondaryId"));
            client.setISP(r.getString("ISP"));
            client.setBillingCycle(r.getInt("BillingCycle"));
            client.setPlanName(r.getString("PlanName"));
            client.setBlockingStatus(r.getInt("BlockingStatus"));
            client.setPlanOverride(r.getString("PlanOverride"));
            var poed = r.getTimestamp("PlanOverrideExpDateUTC");
            client.setPlanOverrideExpDateUTC(poed == null ? null : poed.toInstant());
            client.setAddonProfileOverride(r.getString("AddonProfileOverride"));
            var aoed = r.getTimestamp("AddonProfileOverrideExpDateUTC");
            client.setAddonProfileOverrideExpDateUTC(aoed == null ? null : aoed.toInstant());
            client.setCampaignProfile(r.getString("CampaignProfile"));
            var ced = r.getTimestamp("CampaignExpDateUTC");
            client.setCampaignExpDateUTC(ced == null ? null : ced.toInstant());

            return client;
        };

        var clientList = jdbc.query(sql, clientRowMapper, clientId); 
        if(clientList.size() == 0) return Optional.empty(); else return Optional.of(clientList.get(0));
    }
}
