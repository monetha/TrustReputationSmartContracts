pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import './Restricted.sol';


/**
 *  @title MerchantDealsHistory
 *  Contract stores hash of deal conditions together with parties reputation for each deal
 *  This history enables to see evolution of trust rating for both parties
 */
contract MerchantDealsHistory is Contactable, Restricted {

    string constant VERSION = "0.2";

    ///  Merchant of the acceptor
    string public merchantId;
    
    event DealCompleted(
        uint orderId,
        address clientAddress,
        uint32 clientReputation,
        uint32 merchantReputation,
        bool successful,
        uint dealHash
    );

    /**
     *  @param _merchantId Merchant of the acceptor
     *  @param _orderProcessor Address of Order Processor account, which operates contract
     */
    function MerchantDealsHistory(string _merchantId, address _orderProcessor) public
        Restricted(_orderProcessor)
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
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
        external onlyProcessor
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
}
