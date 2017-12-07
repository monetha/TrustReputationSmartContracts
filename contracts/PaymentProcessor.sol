pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantDealsHistory.sol";
import "./MerchantWallet.sol";
import "./Restricted.sol";


/**
 *  @title PaymentProcessor
 *  Each Merchant has one PaymentProcessor that ensure payment and order processing with Trust and Reputation
 *
 * Payment Processor State Transitions:
 * Null -(addOrder) -> Created
 * Created -(securePay) -> Paid
 * Created -(cancelOrder) -> Cancelled
 * Paid -(refundPayment) -> Refunding
 * Paid -(processPayment) -> Finalized
 * Refunding -(withdrawRefund) -> Refunded
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

    enum State {Null, Created, Paid, Finalized, Refunding, Refunded, Cancelled}

    struct Order {
        State state;
        uint price;
        uint creationTime;
        address paymentAcceptor;
        address originAddress;
    }

    /**
     *  Asserts current state.
     *  @param _state Expected state
     *  @param _orderId Order Id
     */
    modifier atState(uint _orderId, State _state) {
        require(_state == orders[_orderId].state);
        _;
    }

    /**
     *  Performs a transition after function execution.
     *  @param _state Next state
     *  @param _orderId Order Id
     */
    modifier transition(uint _orderId, State _state) {
        _;
        orders[_orderId].state = _state;
    }

    /**
     *  payment Processor sets Monetha Gateway
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
     *  @param _paymentAcceptor order payment acceptor
     *  @param _originAddress buyer address
     *  @param _orderCreationTime order creation time
     */
    function addOrder(
        uint _orderId,
        uint _price,
        address _paymentAcceptor,
        address _originAddress,
        uint _orderCreationTime
    ) external onlyProcessor atState(_orderId, State.Null)
    {
        require(_orderId > 0);
        require(_price > 0);

        orders[_orderId] = Order({
            state: State.Created,
            price: _price,
            creationTime: _orderCreationTime,
            paymentAcceptor: _paymentAcceptor,
            originAddress: _originAddress
        });
    }

    /**
     *  securePay can be used by client if he wants to securely set client address for refund together with payment.
     *  This function require more gas, then fallback function.
     *  @param _orderId Identifier of the order
     */
    function securePay(uint _orderId)
        external payable
        atState(_orderId, State.Created) transition(_orderId, State.Paid)
    {
        Order storage order = orders[_orderId];

        require(msg.sender == order.paymentAcceptor);
        require(msg.value == order.price);
    }

    /**
     *  cancelOrder is used when client doesn't pay and order need to be cancelled.
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _cancelReason Order cancel reason
     */
    function cancelOrder(
        uint _orderId,
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _cancelReason
    )
        external onlyProcessor
        atState(_orderId, State.Created) transition (_orderId, State.Cancelled)
    {
        Order storage order = orders[_orderId];

        updateDealConditions(
            _orderId,
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );

        merchantHistory.recordDealCancelReason(
            _orderId,
            order.originAddress,
            _clientReputation,
            _merchantReputation,
            _dealHash,
            _cancelReason
        );
    }

    /**
     *  refundPayment used in case order cannot be processed.
     *  This function initiate process of funds refunding to the client.
     *  @param _orderId Identifier of the order
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _cancelReason Order refund/cancel reason
     */
    function refundPayment(
        uint _orderId,
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _cancelReason
    )   
        external onlyProcessor
        atState(_orderId, State.Paid) transition(_orderId, State.Refunding)
    {
        Order storage order = orders[_orderId];

        updateDealConditions(
            _orderId,
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );

        merchantHistory.recordDealCancelReason(
            _orderId,
            order.originAddress,
            _clientReputation,
            _merchantReputation,
            _dealHash,
            _cancelReason
        );
    }

    /**
     *  withdrawRefund performs fund transfer to the client's account.
     *  @param _orderId Identifier of the order
     */
    function withdrawRefund(uint _orderId) 
        external
        atState(_orderId, State.Refunding) transition(_orderId, State.Refunded) 
    {
        Order storage order = orders[_orderId];
        order.originAddress.transfer(order.price);
    }

    /**
     *  processPayment transfer funds to MonethaGateway and completes the order.
     *  @param _orderId Identifier of the order
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function processPayment(
        uint _orderId,
        MerchantWallet _merchantWallet, //merchantWallet is passing as a parameter
                                        //for possibility to dynamically change it,
                                        //if merchant requests for change
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    )
        external onlyProcessor
        atState(_orderId, State.Paid) transition(_orderId, State.Finalized)
    {
        monethaGateway.acceptPayment.value(orders[_orderId].price)(_merchantWallet);

        updateDealConditions(
            _orderId,
            _merchantWallet,
            _clientReputation,
            _merchantReputation,
            true,
            _dealHash
        );
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
     *  updateDealConditions record finalized deal and updates merchant reputation
     *  in future: update Client reputation
     *  @param _orderId Identifier of the order
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation is stored
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _isSuccess Identifies whether deal was successful or not
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function updateDealConditions(
        uint _orderId,
        MerchantWallet _merchantWallet,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        bool _isSuccess,
        uint _dealHash
    ) internal
    {
       merchantHistory.recordDeal(
            _orderId,
            orders[_orderId].originAddress,
            _clientReputation,
            _merchantReputation,
            _isSuccess,
            _dealHash
        );

        //update parties Reputation
        _merchantWallet.setCompositeReputation("total", _merchantReputation);
    }
}
