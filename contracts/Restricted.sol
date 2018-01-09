pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


/** @title Restricted
 *  Exposes onlyProcessor modifier
 */
contract Restricted is Ownable {

    address public processor;


    function Restricted(address _processor) public {
        require(_processor != 0x0);
        processor = _processor;
    }

    /**
     *  Restrict methods in such way, that they can be invoked only by processor account.
     *  Restricted methods can be called indirectly, through internal transactions
     *  Processor account must be an originator of an initial transaction
     *  
     *  ***IMPORTANT***
     *  Usage of tx.origin can lead to critical security vulnerability
     *  In order to prevent this, processor should *not* interact with unknown contracts
     *  All calls, that processor can do, should not contain internal transactions to unknown addresses
     */
    modifier onlyProcessor() {
        require(tx.origin == processor);
        _;
    }

    /**
     *  Allows owner to set new processor account address
     */
    function setProcessor(address _newProcessor) onlyOwner public {
        require(_newProcessor != 0x0);
        processor = _newProcessor;
    }

}
