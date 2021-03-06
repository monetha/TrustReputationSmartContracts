pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
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
 *  Payment Processor State Transitions:
 *  Null -(addOrder) -> Created
 *  Created -(securePay) -> Paid
 *  Created -(cancelOrder) -> Cancelled
 *  Paid -(refundPayment) -> Refunding
 *  Paid -(processPayment) -> Finalized
 *  Refunding -(withdrawRefund) -> Refunded
 */


contract PaymentProcessor is Pausable, Destructible, Contactable, Restricted {

    using SafeMath for uint256;

    string constant VERSION = "0.4";

    /**
     *  Fee permille of Monetha fee.
     *  1 permille = 0.1 %
     *  15 permille = 1.5%
     */
    uint public constant FEE_PERMILLE = 15;

    /// MonethaGateway contract for payment processing
    MonethaGateway public monethaGateway;

    /// MerchantDealsHistory contract of acceptor's merchant
    MerchantDealsHistory public merchantHistory;

    /// Address of MerchantWallet, where merchant reputation and funds are stored
    MerchantWallet public merchantWallet;

    /// Merchant identifier hash, that associates with the acceptor
    bytes32 public merchantIdHash;

    mapping (uint=>Order) public orders;

    enum State {Null, Created, Paid, Finalized, Refunding, Refunded, Cancelled}

    struct Order {
        State state;
        uint price;
        uint fee;
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
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation and funds are stored
     */
    function PaymentProcessor(
        string _merchantId,
        MerchantDealsHistory _merchantHistory,
        MonethaGateway _monethaGateway,
        MerchantWallet _merchantWallet
    ) public
    {
        require(bytes(_merchantId).length > 0);

        merchantIdHash = keccak256(_merchantId);

        setMonethaGateway(_monethaGateway);
        setMerchantWallet(_merchantWallet);
        setMerchantDealsHistory(_merchantHistory);
    }

    /**
     *  Assigns the acceptor to the order (when client initiates order).
     *  @param _orderId Identifier of the order
     *  @param _price Price of the order 
     *  @param _paymentAcceptor order payment acceptor
     *  @param _originAddress buyer address
     *  @param _fee Monetha fee
     */
    function addOrder(
        uint _orderId,
        uint _price,
        address _paymentAcceptor,
        address _originAddress,
        uint _fee
    ) external onlyMonetha whenNotPaused atState(_orderId, State.Null)
    {
        require(_orderId > 0);
        require(_price > 0);
        require(_fee >= 0 && _fee <= FEE_PERMILLE.mul(_price).div(1000)); // Monetha fee cannot be greater than 1.5% of price

        orders[_orderId] = Order({
            state: State.Created,
            price: _price,
            fee: _fee,
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
        external payable whenNotPaused
        atState(_orderId, State.Created) transition(_orderId, State.Paid)
    {
        Order storage order = orders[_orderId];

        require(msg.sender == order.paymentAcceptor);
        require(msg.value == order.price);
    }

    /**
     *  cancelOrder is used when client doesn't pay and order need to be cancelled.
     *  @param _orderId Identifier of the order
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _cancelReason Order cancel reason
     */
    function cancelOrder(
        uint _orderId,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _cancelReason
    )
        external onlyMonetha whenNotPaused
        atState(_orderId, State.Created) transition(_orderId, State.Cancelled)
    {
        require(bytes(_cancelReason).length > 0);

        Order storage order = orders[_orderId];

        updateDealConditions(
            _orderId,
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
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _refundReason Order refund reason, order will be moved to State Cancelled after Client withdraws money
     */
    function refundPayment(
        uint _orderId,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _refundReason
    )   
        external onlyMonetha whenNotPaused
        atState(_orderId, State.Paid) transition(_orderId, State.Refunding)
    {
        require(bytes(_refundReason).length > 0);

        Order storage order = orders[_orderId];

        updateDealConditions(
            _orderId,
            _clientReputation,
            _merchantReputation,
            false,
            _dealHash
        );

        merchantHistory.recordDealRefundReason(
            _orderId,
            order.originAddress,
            _clientReputation,
            _merchantReputation,
            _dealHash,
            _refundReason
        );
    }

    /**
     *  withdrawRefund performs fund transfer to the client's account.
     *  @param _orderId Identifier of the order
     */
    function withdrawRefund(uint _orderId) 
        external whenNotPaused
        atState(_orderId, State.Refunding) transition(_orderId, State.Refunded) 
    {
        Order storage order = orders[_orderId];
        order.originAddress.transfer(order.price);
    }

    /**
     *  processPayment transfer funds to MonethaGateway and completes the order.
     *  @param _orderId Identifier of the order
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function processPayment(
        uint _orderId,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash
    )
        external onlyMonetha whenNotPaused
        atState(_orderId, State.Paid) transition(_orderId, State.Finalized)
    {
        address fundAddress;
        fundAddress = merchantWallet.merchantFundAddress();

        if (fundAddress != address(0)) {
            monethaGateway.acceptPayment.value(orders[_orderId].price)(fundAddress, orders[_orderId].fee);
        } else {
            monethaGateway.acceptPayment.value(orders[_orderId].price)(merchantWallet, orders[_orderId].fee);
        }
        
        updateDealConditions(
            _orderId,
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
     *  setMerchantWallet allows owner to change address of MerchantWallet.
     *  @param _newWallet Address of new MerchantWallet contract
     */
    function setMerchantWallet(MerchantWallet _newWallet) public onlyOwner {
        require(address(_newWallet) != 0x0);
        require(_newWallet.merchantIdHash() == merchantIdHash);

        merchantWallet = _newWallet;
    }

    /**
     *  setMerchantDealsHistory allows owner to change address of MerchantDealsHistory.
     *  @param _merchantHistory Address of new MerchantDealsHistory contract
     */
    function setMerchantDealsHistory(MerchantDealsHistory _merchantHistory) public onlyOwner {
        require(address(_merchantHistory) != 0x0);
        require(_merchantHistory.merchantIdHash() == merchantIdHash);

        merchantHistory = _merchantHistory;
    }

    /**
     *  updateDealConditions record finalized deal and updates merchant reputation
     *  in future: update Client reputation
     *  @param _orderId Identifier of the order
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _isSuccess Identifies whether deal was successful or not
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function updateDealConditions(
        uint _orderId,
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
        merchantWallet.setCompositeReputation("total", _merchantReputation);
    }
}
