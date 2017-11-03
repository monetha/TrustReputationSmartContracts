pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantDealsHistory.sol";
import "./MerchantWallet.sol";
import "./Restricted.sol";


/**
 * @title PaymentAcceptor
 * Each Merchant is assigned a pool of PaymentAcceptors that ensure payment and order processing with Trust and Reputation
 *
 * Payment Acceptor State Transitions:
 * Inactive -(setMerchant) -> MerchantAssigned
 * MerchantAssigned -(unassignMerchant) -> Inactive
 * MerchantAssigned -(assignOrder) -> OrderAssigned
 * OrderAssigned -(cancelOrder) -> MerchantAssigned
 * OrderAssigned -(setClient) -> Paid
 * OrderAssigned -(securePay) -> Paid
 * Paid -(refundPayment) -> Refunding
 * Refunding -(withdrawRefund) -> MerchantAssigned
 * Paid -(processPayment) -> MerchantAssigned
 */

contract PaymentAcceptor is Destructible, Contactable, Restricted {

    string constant VERSION = "0.2";

    /// MonethaGateway contract for payment processing
    MonethaGateway public monethaGateway;

    /// MerchantDealsHistory contract of acceptor's merchant
    MerchantDealsHistory public merchantHistory;

    /// Merchant of the acceptor
    string public merchantId;

    /// Identifier of the current order
    uint public orderId;

    /// Price of the current order
    uint public price;

    /// Address of the client, who paid the order
    address public client;

    /// Current state of the acceptor
    State public state;

    /// Number of seconds from creationTime, before order will expire
    uint public lifetime;

    /// Time, when order was assigned to the acceptor
    uint public creationTime;

    enum State {Inactive, MerchantAssigned, OrderAssigned, Paid, Refunding}

    /**
     * Asserts current state.
     * @param _state Expected state
     */
    modifier atState(State _state) {
        require(_state == state);
        _;
    }

    /**
     * Performs a transition after function execution.
     * @param _state Next state
     */
    modifier transition(State _state) {
        _;
        state = _state;
    }

    /**
     *  @param _merchantId Merchant of the acceptor
     *  @param _merchantHistory Address of MerchantDealsHistory contract of acceptor's merchant
     *  @param _monethaGateway Address of MonethaGateway contract for payment processing
     *  @param _lifetime Number of seconds from creationTime, before order will expire
     *  @param _orderProcessor Address of Order Processor account, which operates contract
     */
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
        setLifetime(_lifetime);
    }

    /**
     *  Assign merchant to the acceptor.
     *  This method used for transferring unitiallized acceptor from Global Acceptor Pool.
     *  to merchant's pool.
     *  PaymentAcceptor pool is dynamic for Merchant.
     *  @param _merchantId Identifier of the merchant
     *  @param _merchantHistory Address of MerchantDealsHistory contract, which belongs to the merchant
     */
    function setMerchant(string _merchantId, MerchantDealsHistory _merchantHistory) public
        atState(State.Inactive) transition(State.MerchantAssigned) onlyOwner
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
        merchantHistory = _merchantHistory;
    }

    /**
     *  Unassign merchant from the acceptor.
     *  This method used for transferring acceptor back to the Global Acceptor Pool.
     */
    function unassignMerchant() external
        atState(State.MerchantAssigned) transition(State.Inactive) onlyOwner
    {
        merchantId = "";
        merchantHistory = MerchantDealsHistory(0x0);
    }

    /**
     *  Assigns the acceptor to the order (when client initiates order).
     *  @param _orderId Identifier of the order
     *  @param _price Price of the order 
     */
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
     *  cancelOrder is used when client doesn't pay and order need to be cancelled.
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
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

        updateDealConditions(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );

        resetOrder();
    }

    /**
     *  Fallback function accepts payment for the order.
     */
    function () external payable
        atState(State.OrderAssigned)
    {
        require(msg.value == price);
        require(this.balance - msg.value == 0); //the order should not be paid already
        require(now <= creationTime + lifetime);
    }

    /**
     *  securePay can be used by client if he wants to securely set client address for refund together with payment.
     *  This function require more gas, then fallback function.
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
     *  setClient function decoupled from fallback function
     *      in order to remain low gas cost for fallback function
     *      and to enable non-ether payments.
     *  @param _client Address of client's account
     */
    function setClient(address _client) external
        atState(State.OrderAssigned) transition(State.Paid) onlyProcessor
    {
        require(_client != 0x0);
        client = _client;
    }

    /**
     *  refundPayment used in case order cannot be processed.
     *  This function initiate process of funds refunding to the client.
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function refundPayment(
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    )   external
        atState(State.Paid) transition(State.Refunding) onlyProcessor
    {
        updateDealConditions(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );
    }

    /**
     *  withdrawRefund performs fund transfer to the client's account.
     */
    function withdrawRefund() external atState(State.Refunding) transition(State.MerchantAssigned) {
        client.transfer(this.balance);
        resetOrder();
    }

    /**
     *  processPayment transfer funds to MonethaGateway and completes the order.
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
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

        updateDealConditions(
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            true,
            _dealHash
        );

        resetOrder();
    }

    /**
     *  setMonethaGateway allows owner to change address of MonethaGateway.
     *  @param _newGateway Address of new MonethaGateway contract
     */
    function setMonethaGateway(MonethaGateway _newGateway) public onlyOwner {
        require(address(_newGateway) != 0x0);
        monethaGateway = _newGateway;
    }

    /**
     *  setLifetime allows owner to change order lifetime.
     *  @param _lifetime New lifetime of an order
     */
    function setLifetime(uint _lifetime) public onlyOwner {
        require(_lifetime > 0);
        lifetime = _lifetime;
    }

    /**
     * updateDealConditions record finalized deal and updates merchant reputation
     * in future: update Client reputation
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _isSuccess Identifies whether deal was successful or not
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function updateDealConditions(
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

        //update parties Reputation
        _merchantWallet.setCompositeReputation("total", _merchantReputation);
    }

    /**
     *  Reset order assignment of the acceptor
     */
    function resetOrder() internal {
        orderId = 0;
        price = 0;
        creationTime = 0;
    }
}