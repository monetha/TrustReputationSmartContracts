pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./Restricted.sol";
import "./SafeDestructible.sol";

/**
 *  @title MerchantWallet
 *  Serves as a public Merchant profile with merchant profile info, 
 *      payment settings and latest reputation value.
 *  Also MerchantWallet accepts payments for orders.
 */

contract MerchantWallet is Pausable, SafeDestructible, Contactable, Restricted {
    
    string constant VERSION = "0.2";

    /// Address of merchant's account, that can withdraw from wallet
    address public merchantAccount;
    
    /// Unique Merchant identifier
    string public merchantId;

    /// profileMap stores general information about the merchant
    mapping (string=>string) profileMap;

    /// paymentSettingsMap stores payment and order settings for the merchant
    mapping (string=>string) paymentSettingsMap;

    /// compositeReputationMap stores composite reputation, that compraises from several metrics
    mapping (string=>uint32) compositeReputationMap;

    /// number of last digits in compositeReputation for fractional part
    uint8 public constant REPUTATION_DECIMALS = 4;

    modifier onlyMerchant() {
        require(msg.sender == merchantAccount);
        _;
    }

    /**
     *  @param _merchantAccount Address of merchant's account, that can withdraw from wallet
     *  @param _merchantId Merchant identifier
     *  @param _processor Address of Processor account, which operates compositeReputationMap
     */
    function MerchantWallet(address _merchantAccount, string _merchantId, address _processor)
        public Restricted(_processor)
    {
        require(_merchantAccount != 0x0);
        require(bytes(_merchantId).length > 0);
        
        merchantAccount = _merchantAccount;
        merchantId = _merchantId;
    }

    /**
     *  Accept payment from MonethaGateway
     */
    function () external payable {
    }

    /**
     *  @return profile info by string key
     */
    function profile(string key) external constant returns (string) {
        return profileMap[key];
    }

    /**
     *  @return payment setting by string key
     */
    function paymentSettings(string key) external constant returns (string) {
        return paymentSettingsMap[key];
    }

    /**
     *  @return composite reputation value by string key
     */
    function compositeReputation(string key) external constant returns (uint32) {
        return compositeReputationMap[key];
    }

    /**
     *  Set profile info by string key
     */
    function setProfile(
        string profileKey,
        string profileValue,
        string repKey,
        uint32 repValue
    ) external onlyOwner
    {
        profileMap[profileKey] = profileValue;
        
        if (bytes(repKey).length != 0) {
            compositeReputationMap[repKey] = repValue;
        }
    }

    /**
     *  Set payment setting by string key
     */
    function setPaymentSettings(string key, string value) external onlyOwner {
        paymentSettingsMap[key] = value;
    }

    /**
     *  Set composite reputation value by string key
     */
    function setCompositeReputation(string key, uint32 value) external onlyProcessor {
        compositeReputationMap[key] = value;
    }

    /**
     *  Allows merchant to withdraw funds to beneficiary address
     */
    function withdrawTo(address beneficiary, uint amount) public onlyMerchant whenNotPaused {
        require(beneficiary != 0x0);
        beneficiary.transfer(amount);
    }

    /**
     *  Allows merchant to withdraw funds to it's own account
     */
    function withdraw(uint amount) external {
        withdrawTo(msg.sender, amount);
    }

    /**
     *  Allows merchant to change it's account address
     */
    function changeMerchantAccount(address newAccount) external onlyMerchant whenNotPaused {
        merchantAccount = newAccount;
    }
}
