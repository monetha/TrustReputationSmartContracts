pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import './Restricted.sol';


contract MerchantWallet is Pausable, Destructible, Contactable, Restricted {
    
    string constant VERSION = "1.0";

    address public merchantAccount;

    string public merchantId;

    mapping (string=>string) profileMap;
    mapping (string=>string) paymentSettingsMap;
    mapping (string=>uint32) compositeReputationMap;

    uint8 public constant REPUTATION_DECIMALS = 4;

    modifier onlyMerchant() {
        require(msg.sender == merchantAccount);
        _;
    }

    function MerchantWallet(address _merchantAccount, string _merchantId, address _processor)
        public Restricted(_processor)
    {
        require(_merchantAccount != 0x0);
        require(bytes(_merchantId).length > 0);
        
        merchantAccount = _merchantAccount;
        merchantId = _merchantId;
    }
    
    function () external payable {
    }

    function profile(string key) external constant returns (string) {
        return profileMap[key];
    }

    function paymentSettings(string key) external constant returns (string) {
        return paymentSettingsMap[key];
    }

    function compositeReputation(string key) external constant returns (uint32) {
        return compositeReputationMap[key];
    }

    function setProfile(string key, string value) external onlyOwner {
        profileMap[key] = value;
    }

    function setPaymentSettings(string key, string value) external onlyOwner {
        paymentSettingsMap[key] = value;
    }

    function setCompositeReputation(string key, uint32 value) external onlyProcessor {
        compositeReputationMap[key] = value;
    }

    function withdrawTo(address beneficiary, uint amount) public onlyMerchant whenNotPaused {
        require(beneficiary != 0x0);
        beneficiary.transfer(amount);
    }

    function withdraw(uint amount) external {
        withdrawTo(msg.sender, amount);
    }

    function changeMerchantAccount(address newAccount) external onlyMerchant whenNotPaused {
        merchantAccount = newAccount;
    }
}
