pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract PaymentAcceptor is Destructible, Contactable {

    string constant VERSION = "1.0";
    
    address public merchant;
    uint public orderId;
    uint public price;

    function PaymentAcceptor(address _merchant) {
        merchant = _merchant;
    }

    //to be able to return back merchant from Merchant's Pool to Global Reserve Pool
    function setMerchant(address _merchant) external onlyOwner {
        merchant = _merchant;
    }

    function () external payable {
        require(merchant != 0x0);
        require(orderId != 0);
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already
    }

    function assignOrder(uint _orderId, uint _price, address _merchant) external onlyOwner {
        require(merchant == _merchant);
        orderId = _orderId;
        price = _price;
    }

    function processPayment(address beneficiary) external onlyOwner {
        beneficiary.transfer(this.balance);
        orderId = 0;
        price = 0;
    }
}
