pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaGateway.sol";
import "./MerchantWallet.sol";
import "./Restricted.sol";

contract PrivatePaymentProcessor is Pausable, Destructible, Contactable, Restricted {

    using SafeMath for uint256;

    string constant VERSION = "0.4";

    // Order paid event
    event OrderPaid(
        uint indexed _orderId,
        address indexed _originAddress,
        uint _price,
        uint _monethaFee
    );

    // Payments have been processed event
    event PaymentsProcessed(
        address indexed _merchantAddress,
        uint _amount,
        uint _fee
    );

    // PaymentRefunding is an event when refunding initialized
    event PaymentRefunding(
         uint indexed _orderId,
         address indexed _clientAddress,
         uint _amount,
         string _refundReason);

    // PaymentWithdrawn event is fired when payment is withdrawn
    event PaymentWithdrawn(
        uint indexed _orderId,
        address indexed _clientAddress,
        uint amount);

    /// MonethaGateway contract for payment processing
    MonethaGateway public monethaGateway;

    /// Address of MerchantWallet, where merchant reputation and funds are stored
    MerchantWallet public merchantWallet;

    /// Merchant identifier hash, that associates with the acceptor
    bytes32 public merchantIdHash;

    enum WithdrawState {Null, Pending, Withdrawn}

    struct Withdraw {
        WithdrawState state;
        uint amount;
        address clientAddress;
    }

    mapping (uint=>Withdraw) public withdrawals;

    /**
     *  Private Payment Processor sets Monetha Gateway and Merchant Wallet.
     *  @param _merchantId Merchant of the acceptor
     *  @param _monethaGateway Address of MonethaGateway contract for payment processing
     *  @param _merchantWallet Address of MerchantWallet, where merchant reputation and funds are stored
     */
    function PrivatePaymentProcessor(
        string _merchantId,
        MonethaGateway _monethaGateway,
        MerchantWallet _merchantWallet
    ) public
    {
        require(bytes(_merchantId).length > 0);

        merchantIdHash = keccak256(_merchantId);

        setMonethaGateway(_monethaGateway);
        setMerchantWallet(_merchantWallet);
    }

    /**
     *  payForOrder is used by order wallet/client to pay for the order
     *  @param _orderId Identifier of the order
     *  @param _originAddress buyer address
     *  @param _monethaFee is fee collected by Monetha
     */
    function payForOrder(
        uint _orderId,
        address _originAddress,
        uint _monethaFee
    ) external payable whenNotPaused
    {
        require(_orderId > 0);
        require(_originAddress != 0x0);
        require(msg.value > 0);

        address fundAddress;
        fundAddress = merchantWallet.merchantFundAddress();

        if (fundAddress != address(0)) {
            monethaGateway.acceptPayment.value(msg.value)(fundAddress, _monethaFee);
        } else {
            monethaGateway.acceptPayment.value(msg.value)(merchantWallet, _monethaFee);
        }
        

        // log payment event
        OrderPaid(_orderId, _originAddress, msg.value, _monethaFee);
    }

    /**
     *  refundPayment used in case order cannot be processed and funds need to be returned
     *  This function initiate process of funds refunding to the client.
     *  @param _orderId Identifier of the order
     *  @param _clientAddress is an address of client
     *  @param _refundReason Order refund reason
     */
    function refundPayment(
        uint _orderId,
        address _clientAddress,
        string _refundReason
    ) external payable onlyMonetha whenNotPaused
    {
        require(_orderId > 0);
        require(_clientAddress != 0x0);
        require(msg.value > 0);
        require(WithdrawState.Null == withdrawals[_orderId].state);

        // create withdraw
        withdrawals[_orderId] = Withdraw({
            state: WithdrawState.Pending,
            amount: msg.value,
            clientAddress: _clientAddress
            });

        // log refunding
        PaymentRefunding(_orderId, _clientAddress, msg.value, _refundReason);
    }

    /**
     *  withdrawRefund performs fund transfer to the client's account.
     *  @param _orderId Identifier of the order
     */
    function withdrawRefund(uint _orderId)
    external whenNotPaused
    {
        Withdraw storage withdraw = withdrawals[_orderId];
        require(WithdrawState.Pending == withdraw.state);

        address clientAddress = withdraw.clientAddress;
        uint amount = withdraw.amount;

        // changing withdraw state before transfer
        withdraw.state = WithdrawState.Withdrawn;

        // transfer fund to clients account
        clientAddress.transfer(amount);

        // log withdrawn
        PaymentWithdrawn(_orderId, clientAddress, amount);
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
}