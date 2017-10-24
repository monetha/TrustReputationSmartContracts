pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantDealsHistory.sol";


contract PaymentAcceptor is Destructible, Contactable {

    string constant VERSION = "1.0";
    
    MonethaGateway public monethaGateway;
    string public merchantId;
    uint public orderId;
    uint public price;
    address public client;
    State public state;

    enum State {Inactive, MerchantAssigned, OrderAssigned, Paid}

    modifier atState(State _state) {
        require(_state == state);
        _;
    }

    modifier transition(State _state) {
        _;
        state = _state;
    }

    function PaymentAcceptor(string _merchantId, MonethaGateway _monethaGateway) {
        changeMonethaGateway(_monethaGateway);
        setMerchantId(_merchantId);
    }

    function setMerchantId(string _merchantId) public
        atState(State.Inactive) transition(State.MerchantAssigned) onlyOwner 
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
    }

    function unassignMerchant() external
        atState(State.MerchantAssigned) transition(State.Inactive) onlyOwner
    {
        merchantId = "";
    }

    function assignOrder(uint _orderId, uint _price) external
        atState(State.MerchantAssigned) transition(State.OrderAssigned) onlyOwner 
    {
        require(_orderId != 0);
        require(_price != 0);

        orderId = _orderId;
        price = _price;
    }

    function () external payable
        atState(State.OrderAssigned) transition(State.Paid) 
    {
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already

        client = msg.sender;
    }

    function refundPayment(MerchantDealsHistory _merchantHistory, uint dealHash) external
        atState(State.Paid) transition(State.MerchantAssigned) onlyOwner
    {
        client.transfer(this.balance);
        _merchantHistory.recordDeal(orderId, client, false, _dealHash);
    }

    function cancelOrder(
        address _merchantWallet,
        MerchantDealsHistory _merchantHistory,
        uint _dealHash) 
        external 
        atState(State.OrderAssigned) transition(State.MerchantAssigned) onlyOwner
    {
        //when client doesn't pay order is cancelled
        //future: update Client reputation

        //reduce BuyerReputation

        orderId = 0;
        price = 0;
    }

    function processPayment(
        address _merchantWallet,
        uint _merchantReputation,
        uint _clientReputation,
        MerchantDealsHistory _merchantHistory,
        uint _dealHash) 
        external 
        atState(State.Paid) transition(State.MerchantAssigned) onlyOwner 
    {
        monethaGateway.acceptPayment.value(this.balance)(_merchantWallet);

        //update ClientReputation()
        //monethaGateway.updateMerchantReputation()
        
        _merchantHistory.recordDeal(orderId, client, _clientReputation, _merchantReputation, true, _dealHash);

        orderId = 0;
        price = 0;
    }

    function changeMonethaGateway(MonethaGateway _newGateway) public onlyOwner {
        require(address(_newGateway) != 0x0);
        monethaGateway = _newGateway;
    }
}