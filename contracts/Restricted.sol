pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


contract Restricted is Ownable {

    address public processor;


    function Restricted(address _processor) public {
        require(_processor != 0x0);
        processor = _processor;
    }

    modifier onlyProcessor() {
        require(tx.origin == processor);
        _;
    }

    function setProcessor(address _newProcessor) onlyOwner public {
        require(_newProcessor != 0x0);
        processor = _newProcessor;
    }

}
