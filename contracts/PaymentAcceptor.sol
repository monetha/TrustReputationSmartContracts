pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantDealsHistory.sol";
import "./MerchantWallet.sol";
import "./Restricted.sol";


/**
 * @title PaymentProcessor
 * Each Merchant has one PaymentProcessor that ensure payment and order processing with Trust and Reputation
 *
 * Payment Acceptor State Transitions:
 * Inactive -(setMerchant) -> MerchantAssigned
 * MerchantAssigned -(unassignMerchant) -> Inactive
 * MerchantAssigned -(addOrder) -> OrderAssigned
 * OrderAssigned -(cancelOrder) -> MerchantAssigned
 * OrderAssigned -(setClient) -> Paid
 * OrderAssigned -(securePay) -> Paid
 * Paid -(refundPayment) -> Refunding
 * Refunding -(withdrawRefund) -> MerchantAssigned
 * Paid -(processPayment) -> MerchantAssigned
 */

contract PaymentProcessor is Destructible, Contactable, Restricted {

    using SafeMath for uint256;

    string constant VERSION = "0.3";

    /// MonethaGateway contract for payment processing
    MonethaGateway public monethaGateway;

    /// MerchantDealsHistory contract of acceptor's merchant
    MerchantDealsHistory public merchantHistory;

    /// Merchant identifier, that associates with the acceptor
    string public merchantId;

    mapping (uint=>Order) public orders;

    enum State {Null, Paid, Refunding}

    struct Order {
        State state;
        uint price;
        uint creationTime;
        address paymentAcceptor;
    }

    /**
     * Asserts current state.
     * @param _state Expected state
     */
    modifier atState(uint orderId, State _state) {
        require(_state == orders[orderId].state);
        _;
    }

    /**
     * Performs a transition after function execution.
     * @param _state Next state
     */
    modifier transition(uint orderId, State _state) {
        _;
        orders[orderId].state = _state;
    }

    /**
     *  @param _merchantId Merchant of the acceptor
     *  @param _merchantHistory Address of MerchantDealsHistory contract of acceptor's merchant
     *  @param _monethaGateway Address of MonethaGateway contract for payment processing
     *  @param _processingAccount Address of Order Processor account, which operates contract
     */
    function PaymentProcessor(
        string _merchantId,
        MerchantDealsHistory _merchantHistory,
        MonethaGateway _monethaGateway,
        address _processingAccount
    ) Restricted(_processingAccount)
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
        merchantHistory = _merchantHistory;

        setMonethaGateway(_monethaGateway);
    }

    /**
     *  Assigns the acceptor to the order (when client initiates order).
     *  @param _orderId Identifier of the order
     *  @param _price Price of the order 
     */
    function addOrder(uint _orderId, uint _price) external onlyProcessor
    {
        require(_orderId != 0);
        require(_price != 0);

        orderId = _orderId;
        price = _price;
        creationTime = now;
        orders[_orderId] = Order({
            state: State.Paid,
            price: _price,
            paymentTime: now,
            paymentAcceptor: msg.sender
        });
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
        require(now > creationTime.add(lifetime));

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
        require(this.balance.sub(msg.value) == 0); //the order should not be paid already
        require(now <= creationTime.add(lifetime));
    }

    /**
     *  securePay can be used by client if he wants to securely set client address for refund together with payment.
     *  This function require more gas, then fallback function.
     */
    function securePay() external payable
        atState(State.OrderAssigned) transition(State.Paid)
    {
        require(msg.value == price);
        require(this.balance.sub(msg.value) == 0); //the order should not be paid already
        require(now <= creationTime.add(lifetime));

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