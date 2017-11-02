pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import './Restricted.sol';

/**
 * Order conditions together with parties reputation is stored for each deal
 * This history enables to see evolution of trust rating for both parties
 */

contract MerchantDealsHistory is Contactable, Restricted {

    string constant VERSION = "1.0";

    string public merchantId;
    
    event DealCompleted(
        uint orderId,
        address clientAddress,
        uint32 clientReputation,
        uint32 merchantReputation,
        bool successful,
        uint dealHash
    );

    function MerchantDealsHistory(string _merchantId, address _orderProcessor) public
        Restricted(_orderProcessor)
    {
        require(bytes(_merchantId).length > 0);
        merchantId = _merchantId;
    }

    function recordDeal(
        uint _orderId,
        address _clientAddress,
        uint32 _clientReputation,
        uint32 _merchantReputation,
        bool _successful,
        uint _dealHash)
        external onlyProcessor
    {
        DealCompleted(
            _orderId,
            _clientAddress,
            _clientReputation,
            _merchantReputation,
            _successful,
            _dealHash
        );
    }
}
