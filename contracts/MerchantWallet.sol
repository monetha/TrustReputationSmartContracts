pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract MerchantWallet is Pausable, Destructible, Contactable {
    
    string constant VERSION = "1.0";

    address public merchantAccount;

    string public merchantId;

    mapping (string=>string) profileMap;
    mapping (string=>string) paymentSettingsMap;
    mapping (string=>uint) compositeReputationMap;

    modifier onlyMerchant() {
        require(msg.sender == merchantAccount);
        _;
    }

    function MerchantWallet(address _merchantAccount, string _merchantId) {
        require(_merchantAccount != 0x0);
        require(bytes(_merchantId).length > 0);
        
        merchantAccount = _merchantAccount;
        merchantId = _merchantId;
    }
    
    function () payable {
    }

    function profile(string key) public constant returns (string) {
        return profileMap[key];
    }

    function paymentSettings(string key) public constant returns (string) {
        return paymentSettingsMap[key];
    }

    function compositeReputation(string key) public constant returns (string) {
        return compositeReputationMap[key];
    }

    function setProfile(string key, string value) public onlyOwner {
        profileMap[key] = value;
    }

    function setPaymentSettings(string key, string value) public onlyOwner {
        paymentSettingsMap[key] = value;
    }

    function setCompositeReputation(string key, uint value) public onlyOwner {
        compositeReputationMap[key] = value;
    }

    function withdraw(address beneficiary, uint amount) public onlyMerchant whenNotPaused {
        require(beneficiary != 0x0);
        beneficiary.transfer(amount);
    }

    function withdraw(uint amount) public {
        withdraw(msg.sender, amount);
    }

    function changeMerchantAccount(address newAccount) public onlyMerchant whenNotPaused {
        merchantAccount = newAccount;
    }
}
