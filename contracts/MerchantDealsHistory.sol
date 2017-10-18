pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract MerchantDealsHistory is Contactable {

    string constant VERSION = "1.0";

    string public merchantId;
    address orderProcessor;
    
    event DealCompleted(uint indexed orderId, address indexed clientAddress, bool successful, uint dealHash);

    function MerchantDealsHistory(string _merchantId, address _orderProcessor) public {
        require(bytes(_merchantId).length > 0);
        require(_orderProcessor != 0x0);
        
        merchantId = _merchantId;
        orderProcessor = _orderProcessor;
    }

    function recordDeal(
        uint _orderId,
        address _clientAddress,
        bool _successful,
        uint _dealHash)
        external
    {
        require(tx.origin == orderProcessor);
        
        DealCompleted(
            _orderId,
            _clientAddress,
            _successful,
            _dealHash
        );
    }

    function changeOrderProcessor(address newOrderProcessor) external onlyOwner {
        orderProcessor = newOrderProcessor;
    }

}
