package com.indra.telco.psba;

import java.time.Instant;

public class Client {
    
    private int clientId;
    private String externalClientId;
    private String contractId;
    private String personalId;
    private String secondaryId;
    private String ISP;
    private int billingCycle;
    private String planName;
    private int blockingStatus;
    private String planOverride;
    private Instant planOverrideExpDateUTC;
    private String addonProfileOverride;
    private Instant addonProfileOverrideExpDateUTC;
    private String CampaignProfile;
    private Instant CampaignExpDateUTC;

    public int getClientId() {
        return clientId;
    }
    public void setClientId(int clientId) {
        this.clientId = clientId;
    }
    public String getExternalClientId() {
        return externalClientId;
    }
    public void setExternalClientId(String externalClientId) {
        this.externalClientId = externalClientId;
    }
    public String getContractId() {
        return contractId;
    }
    public void setContractId(String contractId) {
        this.contractId = contractId;
    }
    public String getPersonalId() {
        return personalId;
    }
    public void setPersonalId(String personalId) {
        this.personalId = personalId;
    }
    public String getSecondaryId() {
        return secondaryId;
    }
    public void setSecondaryId(String secondaryId) {
        this.secondaryId = secondaryId;
    }
    public String getISP() {
        return ISP;
    }
    public void setISP(String iSP) {
        ISP = iSP;
    }
    public int getBillingCycle() {
        return billingCycle;
    }
    public void setBillingCycle(int billingCycle) {
        this.billingCycle = billingCycle;
    }
    public String getPlanName() {
        return planName;
    }
    public void setPlanName(String planName) {
        this.planName = planName;
    }
    public int getBlockingStatus() {
        return blockingStatus;
    }
    public void setBlockingStatus(int blockingStatus) {
        this.blockingStatus = blockingStatus;
    }
    public String getPlanOverride() {
        return planOverride;
    }
    public void setPlanOverride(String planOverride) {
        this.planOverride = planOverride;
    }
    public Instant getPlanOverrideExpDateUTC() {
        return planOverrideExpDateUTC;
    }
    public void setPlanOverrideExpDateUTC(Instant planOverrideExpDateUTC) {
        this.planOverrideExpDateUTC = planOverrideExpDateUTC;
    }
    public String getAddonProfileOverride() {
        return addonProfileOverride;
    }
    public void setAddonProfileOverride(String addonProfileOverride) {
        this.addonProfileOverride = addonProfileOverride;
    }
    public Instant getAddonProfileOverrideExpDateUTC() {
        return addonProfileOverrideExpDateUTC;
    }
    public void setAddonProfileOverrideExpDateUTC(Instant addonProfileOverrideExpDateUTC) {
        this.addonProfileOverrideExpDateUTC = addonProfileOverrideExpDateUTC;
    }
    public String getCampaignProfile() {
        return CampaignProfile;
    }
    public void setCampaignProfile(String campaignProfile) {
        CampaignProfile = campaignProfile;
    }
    public Instant getCampaignExpDateUTC() {
        return CampaignExpDateUTC;
    }
    public void setCampaignExpDateUTC(Instant campaignExpDateUTC) {
        CampaignExpDateUTC = campaignExpDateUTC;
    }
    
    @Override
    public String toString() {
        return "Client [clientId=" + clientId + ", externalClientId=" + externalClientId + ", contractId=" + contractId
                + ", personalId=" + personalId + ", secondaryId=" + secondaryId + ", ISP=" + ISP + ", billingCycle="
                + billingCycle + ", planName=" + planName + ", blockingStatus=" + blockingStatus + ", planOverride="
                + planOverride + ", planOverrideExpDateUTC=" + planOverrideExpDateUTC + ", addonProfileOverride="
                + addonProfileOverride + ", addonProfileOverrideExpDateUTC=" + addonProfileOverrideExpDateUTC
                + ", CampaignProfile=" + CampaignProfile + ", CampaignExpDateUTC=" + CampaignExpDateUTC + "]";
    }
}
