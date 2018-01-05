pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


/** @title Restricted
 *  Exposes onlyMonetha modifier
 */
contract Restricted is Ownable {

    address public monethaAddress;


    function Restricted(address _monethaAddress) public {
        monethaAddress = _monethaAddress;
    }

    /**
     *  Restrict methods in such way, that they can be invoked only by monethaAddress account.
     */
    modifier onlyMonetha() {
        require(msg.sender == monethaAddress);
        _;
    }

    /**
     *  Allows owner to set new monethaAddress account address
     */
    function setMonethaAddress(address _newMonethaAddress) onlyOwner public {
        require(_newMonethaAddress != 0x0);
        monethaAddress = _newMonethaAddress;
    }

}
