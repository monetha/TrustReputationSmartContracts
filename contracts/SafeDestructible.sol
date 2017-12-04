pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title SafeDestructible
 * Base contract that can be destroyed by owner.
 * Can be destructed if there are no funds on contract balance.
 */
contract SafeDestructible is Ownable {
    function destroy() onlyOwner public {
        require(this.balance == 0);
        selfdestruct(owner);
    }
}