pragma solidity 0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./Restricted.sol";


/**
 *  @title MonethaGateway
 *
 *  MonethaGateway forward funds from order payment to merchant's wallet and collects Monetha fee.
 */
contract MonethaGateway is Pausable, Contactable, Destructible, Restricted {

    using SafeMath for uint256;
    
    string constant VERSION = "0.3";

    /**
     *  Fee permille of Monetha fee.
     *  1 permille (‰) = 0.1 percent (%)
     *  15‰ = 1.5%
     */
    uint public constant FEE_PERMILLE = 15;
    
    /**
     *  Address of Monetha Vault for fee collection
     */
    address public monethaVault;

    event PaymentProcessed(address merchantWallet, uint merchantIncome, uint monethaIncome);

    /**
     *  @param _monethaVault Address of Monetha Vault
     */
    function MonethaGateway(address _monethaVault, address _processingAccount) public {
        require(_monethaVault != 0x0);
        monethaVault = _monethaVault;
        
        require(_processingAccount != 0x0);
        isMonethaAddress[_processingAccount] = true;
    }
    
    /**
     *  acceptPayment accept payment from PaymentAcceptor, forwards it to merchant's wallet
     *      and collects Monetha fee.
     *  @param _merchantWallet address of merchant's wallet for fund transfer
     */
    function acceptPayment(address _merchantWallet) external payable onlyMonetha whenNotPaused {
        require(_merchantWallet != 0x0);

        uint merchantIncome = msg.value.sub(FEE_PERMILLE.mul(msg.value).div(1000));
        uint monethaIncome = msg.value.sub(merchantIncome);

        _merchantWallet.transfer(merchantIncome);
        monethaVault.transfer(monethaIncome);

        PaymentProcessed(_merchantWallet, merchantIncome, monethaIncome);
    }

    /**
     *  changeMonethaVault allows owner to change address of Monetha Vault.
     *  @param newVault New address of Monetha Vault
     */
    function changeMonethaVault(address newVault) external onlyOwner whenNotPaused {
        monethaVault = newVault;
    }

    /**
     *  Allows other monetha account or contract to set new monetha address
     */
    function setMonethaAddress(address _address, bool _isMonethaAddress) onlyMonetha public {
        isMonethaAddress[_address] = _isMonethaAddress;
    }
}
