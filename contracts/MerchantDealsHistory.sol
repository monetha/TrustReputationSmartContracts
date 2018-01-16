pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import './Restricted.sol';


/**
 *  @title MerchantDealsHistory
 *  Contract stores hash of Deals conditions together with parties reputation for each deal
 *  This history enables to see evolution of trust rating for both parties
 */
contract MerchantDealsHistory is Contactable, Restricted {

    string constant VERSION = "0.3";

    ///  Merchant identifier hash
    bytes32 public merchantIdHash;
    
    //Deal event
    event DealCompleted(
        uint orderId,
        address clientAddress,
        uint32 clientReputation,
        uint32 merchantReputation,
        bool successful,
        uint dealHash
    );

    //Deal cancellation event
    event DealCancelationReason(
        uint orderId,
        address clientAddress,
        uint32 clientReputation,
        uint32 merchantReputation,
        uint dealHash,
        string cancelReason
    );

    //Deal refund event
    event DealRefundReason(
        uint orderId,
        address clientAddress,
        uint32 clientReputation,
        uint32 merchantReputation,
        uint dealHash,
        string refundReason
    );

    /**
     *  @param _merchantId Merchant of the acceptor
     */
    function MerchantDealsHistory(string _merchantId) public {
        require(bytes(_merchantId).length > 0);
        merchantIdHash = keccak256(_merchantId);
    }

    /**
     *  recordDeal creates an event of completed deal
     *  @param _orderId Identifier of deal's order
     *  @param _clientAddress Address of client's account
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _isSuccess Identifies whether deal was successful or not
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     */
    function recordDeal(
        uint _orderId,
        address _clientAddress,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        bool _isSuccess,
        uint _dealHash)
        external onlyMonetha
    {
        DealCompleted(
            _orderId,
            _clientAddress,
            _clientReputation,
            _merchantReputation,
            _isSuccess,
            _dealHash
        );
    }

    /**
     *  recordDealCancelReason creates an event of not paid deal that was cancelled 
     *  @param _orderId Identifier of deal's order
     *  @param _clientAddress Address of client's account
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _cancelReason deal cancelation reason (text)
     */
    function recordDealCancelReason(
        uint _orderId,
        address _clientAddress,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _cancelReason)
        external onlyMonetha
    {
        DealCancelationReason(
            _orderId,
            _clientAddress,
            _clientReputation,
            _merchantReputation,
            _dealHash,
            _cancelReason
        );
    }

/**
     *  recordDealRefundReason creates an event of not paid deal that was cancelled 
     *  @param _orderId Identifier of deal's order
     *  @param _clientAddress Address of client's account
     *  @param _clientReputation Updated reputation of the client
     *  @param _merchantReputation Updated reputation of the merchant
     *  @param _dealHash Hashcode of the deal, describing the order (used for deal verification)
     *  @param _refundReason deal refund reason (text)
     */
    function recordDealRefundReason(
        uint _orderId,
        address _clientAddress,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        uint _dealHash,
        string _refundReason)
        external onlyMonetha
    {
        DealRefundReason(
            _orderId,
            _clientAddress,
            _clientReputation,
            _merchantReputation,
            _dealHash,
            _refundReason
        );
    }
}
