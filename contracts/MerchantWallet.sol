pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract MerchantWallet is Pausable, Destructible, Contactable {

    address public merchantAccount;

    mapping (string=>string) profileMap;
    mapping (string=>string) paymentSettingsMap;
    mapping (string=>string) compositeReputationMap;

    function MerchantWallet(address _merchantAccount) {
        require(_merchantAccount != 0x0);
        merchantAccount = _merchantAccount;
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

    function setCompositeReputation(string key, string value) public onlyOwner {
        compositeReputationMap[key] = value;
    }

    function withdraw(address beneficiary, uint amount) public {
        require(beneficiary != 0x0);
        require(msg.sender == merchantAccount);

        beneficiary.transfer(amount);
    }

    function withdraw(uint amount) public {
        withdraw(msg.sender, amount);
    }
}
