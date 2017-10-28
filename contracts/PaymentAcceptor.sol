pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantDealsHistory.sol";
import "./MerchantWallet.sol";
import "./Restricted.sol";


/**
 * State transitions:
 *
 * Inactive -(setMerchant)-> MerchantAssigned
 * MerchantAssigned -(unassignMerchant)-> Inactive
 * MerchantAssigned -(assignOrder)-> OrderAssigned
 * OrderAssigned -(cancelOrder)-> MerchantAssigned
 * OrderAssigned -(setClient)-> Paid
 * OrderAssigned -(securePay)-> Paid
 * Paid -(refundPayment)-> Refunding
 * Refunding -(withdrawRefund)-> MerchantAssigned
 * Paid -(processPayment)-> MerchantAssigned
 */
contract PaymentAcceptor is Destructible, Contactable, Restricted {

    string constant VERSION = "1.0";
    
    MonethaGateway public monethaGateway;
    MerchantDealsHistory public merchantHistory;
    string public merchantId;
    uint public orderId;
    uint public price;
    address public client;
    State public state;
    uint public lifetime;
    uint public creationTime;

    enum State {Inactive, MerchantAssigned, OrderAssigned, Paid, Refunding}

    modifier atState(State _state) {
        require(_state == state);
        _;
    }

    modifier transition(State _state) {
        _;
        state = _state;
    }

    function PaymentAcceptor(
        string _merchantId,
        MerchantDealsHistory _merchantHistory,
        MonethaGateway _monethaGateway,
        uint _lifetime,
        address _orderProcessor
    ) Restricted(_orderProcessor)
    {
        setMonethaGateway(_monethaGateway);
        setMerchant(_merchantId, _merchantHistory);
        lifetime = _lifetime;
    }

    function setMerchant(string _merchantId, MerchantDealsHistory _merchantHistory) public
        atState(State.Inactive) transition(State.MerchantAssigned) onlyOwner 
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
        merchantHistory = _merchantHistory;
    }

    function unassignMerchant() external
        atState(State.MerchantAssigned) transition(State.Inactive) onlyOwner
    {
        merchantId = "";
        merchantHistory = MerchantDealsHistory(0x0);
    }

    function assignOrder(uint _orderId, uint _price) external
        atState(State.MerchantAssigned) transition(State.OrderAssigned) onlyProcessor 
    {
        require(_orderId != 0);
        require(_price != 0);

        orderId = _orderId;
        price = _price;
        creationTime = now;
    }

    /**
     *  when client doesn't pay order is cancelled
     *  in future: update Client reputation
     */
    function cancelOrder(
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    ) 
        external 
        atState(State.OrderAssigned) transition(State.MerchantAssigned) onlyProcessor
    {
        require(now > creationTime + lifetime);

        //reduce BuyerReputation
        
        updateReputation(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );

        resetOrder();
    }

    function () external payable
        atState(State.OrderAssigned)
    {
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already
        require(now <= creationTime + lifetime);
    }

    /**
     *  securePay can be used by client if he wants to securely set client address for refund
     *  this function require more gas, then fallback function
     */
    function securePay() external payable
        atState(State.OrderAssigned) transition(State.Paid)
    {
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already
        require(now <= creationTime + lifetime);

        client = msg.sender;
    }

    /**
     *  set client function decoupled from fallback function
     *  in order to remain low gas cost for fallback function
     *  and to enable non-ether payments
     */
    function setClient(address _client) external
        atState(State.OrderAssigned) transition(State.Paid) onlyProcessor 
    {
        require(_client != 0x0);
        client = _client;
    }

    function refundPayment(
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    )   external
        atState(State.Paid) transition(State.Refunding) onlyProcessor
    {
        updateReputation(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );
    }

    function withdrawRefund() external atState(State.Refunding) transition(State.MerchantAssigned) {
        client.transfer(this.balance);
        resetOrder();
    }

    function processPayment(
        MerchantWallet _merchantWallet, //merchantWallet is passing as a parameter 
                                        //for possibility to dynamically change it, 
                                        //if merchant requests for change
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    ) 
        external
        atState(State.Paid) transition(State.MerchantAssigned) onlyProcessor 
    {
        monethaGateway.acceptPayment.value(this.balance)(_merchantWallet);

        //update ClientReputation()
        
        updateReputation(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            true,
            _dealHash
        );

        resetOrder();
    }

    function setMonethaGateway(MonethaGateway _newGateway) public onlyOwner {
        require(address(_newGateway) != 0x0);
        monethaGateway = _newGateway;
    }

    function updateReputation(
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        bool _isSuccess,
        uint _dealHash
    ) internal 
    {
        merchantHistory.recordDeal(
            orderId,
            client,
            _clientReputation,
            _merchantReputation,
            _isSuccess,
            _dealHash
        );

        _merchantWallet.setCompositeReputation("total", _merchantReputation);
    }

    function resetOrder() internal {
        orderId = 0;
        price = 0;
        creationTime = 0;
    }
}