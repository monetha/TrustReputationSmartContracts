pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract DealsHistory is Contactable{

    address public merchant;
    address orderProcessor;
    
    event DealCompleted(uint indexed orderId, address indexed clientAddress, uint dealHash);

    function DealsHistory(address _merchant, address _orderProcessor) public {
        merchant = _merchant;
        orderProcessor = _orderProcessor;
    }

    function recordDeal(uint _orderId, address _clientAddress, uint _dealHash) external {
        require(tx.origin == orderProcessor);
        DealCompleted(_orderId, _clientAddress, _dealHash);
    }

}
