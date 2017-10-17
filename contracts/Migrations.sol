pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


contract Migrations is Ownable {

    uint public last_completed_migration;
  
    function setCompleted(uint completed) external onlyOwner {
        last_completed_migration = completed;
    }
  
    function upgrade(address _newAddress) external onlyOwner {
        Migrations upgraded = Migrations(_newAddress);
        upgraded.setCompleted(last_completed_migration);
    }
}
