pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract PaymentAcceptor is Destructible, Contactable {

    uint public orderId;
    uint public price;

    function () external payable {
        require(msg.value == price);
        require(this.balance == 0);
        require(orderId == 0);
    }

    function assignOrder(uint _orderId, uint _price) external onlyOwner {
        orderId = _orderId;
        price = _price;
    }

    function acceptPayment() external onlyOwner {
        orderId = 0;
        price = 0;
        msg.sender.transfer(this.balance);
    }
}
