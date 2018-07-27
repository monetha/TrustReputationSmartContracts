pragma solidity ^0.4.23;

import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./MonethaUsersClaimStorage.sol";


/**
 *  @title MonethaUsersClaimHandler
 *
 *  MonethaUsersClaimHandler contract is a calling contract,
 *  which is used to update the storage contract MonethaUsersClaimStorage.
 */
contract MonethaUsersClaimHandler is Contactable {

    string constant VERSION = "0.1";
    
    MonethaUsersClaimStorage public storageContract;

    event StorageContractOwnerChanged(address indexed _newOwner);

    constructor(address _storageAddr) public {
        storageContract = MonethaUsersClaimStorage(_storageAddr);
    }

    /**
     *  claimTokens calls updateUserClaim function of MonethaUsersClaimStorage contract to update user's token claim status and assign tokens to user.
     *  @param _monethaUser address of user's wallet
     *  @param _tokens corresponds to user's token that is to be claimed.
     */
    function claimTokens(address _monethaUser, uint256 _tokens) external onlyOwner {
        require(storageContract.updateUserClaim(_monethaUser, _tokens));
    }

    /**
     *  claimTokensInBulk calls updateUserClaim function of MonethaUsersClaimStorage contract to update multiple users token claim status and assign tokens to user.
     */
    function claimTokensInBulk(address[] _monethaUsers, uint256[] _tokens) external onlyOwner {
        require(storageContract.updateUserClaimInBulk(_monethaUsers, _tokens));
    }

    /**
     *  deleteAccount deletes user's claimed token
     *  @param _monethaUser address of users wallet
     */
    function deleteAccount(address _monethaUser) external onlyOwner {
        require(storageContract.deleteUserClaim(_monethaUser));
    }

    /**
     *  deleteAccountsInBulk deletes user account in bulk.
     */
    function deleteAccountsInBulk(address[] _monethaUsers) external onlyOwner {
        require(storageContract.deleteUserClaimInBulk(_monethaUsers));
    }

    /**
     *  changeOwnerOfMonethaUsersClaimStorage changes ownership
     *  @param _newOwner address of new owner
     */
    function changeOwnerOfMonethaUsersClaimStorage(address _newOwner) external onlyOwner {
        storageContract.transferOwnership(_newOwner);

        emit StorageContractOwnerChanged(_newOwner);
    }
}
