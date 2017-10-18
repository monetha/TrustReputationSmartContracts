pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract PaymentAcceptor is Destructible, Contactable {

    string constant VERSION = "1.0";
    
    address public merchantAccount;
    address public buyerAccount;

    uint public orderId;
    uint public price;

    function PaymentAcceptor(address _merchantAccount) {
        require(_merchantAccount != 0x0);
        merchantAccount = _merchantAccount;
    }

    //to be able to return back merchantAccount from pool to pool
    function setMerchant(address _merchantAccount) external onlyOwner {
        merchantAccount = _merchantAccount;
    }

    function () external payable {
        require(buyerAccount == 0x0);
        require(merchantAccount != 0x0);
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already
        require(orderId != 0);

        buyerAccount = msg.sender;
    }

    function assignOrder(uint _orderId, uint _price, _merchantAccount) external onlyOwner {
        require(merchantAccount == _merchantAccount);
        orderId = _orderId;
        price = _price;
    }

    function refundPayment(uint _orderId, address _merchantAccount, address _buyerAccount) external onlyMerchant {
        //refund to buyer
        require(merchantAccount == _merchantAccount);
        require(buyerAccount == _buyerAccount);
        require(orderId == _orderId);

        assert(buyerAccount.transfer(this.balance));

        //reset acceptor
        orderId = 0;
        price = 0;
        buyerAccount = 0x0;
    }

    function processPayment(address beneficiary) external onlyOwner {
        assert(beneficiary.transfer(this.balance));
        orderId = 0;
        price = 0;
        buyerAccount = 0x0;
    }
}
