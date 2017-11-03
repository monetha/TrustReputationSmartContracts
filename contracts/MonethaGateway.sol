pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./Restricted.sol";


/**
 *  @title MonethaGateway
 *
 *  MonethaGateway forward funds from order payment to merchant's wallet and collects Monetha fee.
 */
contract MonethaGateway is Contactable, Destructible, Restricted {
    
    string constant VERSION = "0.2";

    /**
     *  Fee permille of Monetha fee.
     *  1 permille (‰) = 0.1 percent (%)
     *  15‰ = 1.5%
     */
    uint8 public constant FEE_PERMILLE = 15;
    
    /**
     *  Address of Monetha Vault for fee collection
     */
    address public monethaVault;

    event PaymentProcessed(address merchantWallet, uint merchantIncome, uint monethaIncome);

    /**
     *  @param _monethaVault Address of Monetha Vault
     *  @param _orderProcessor Address of Order Processor account, which operates contract
     */
    function MonethaGateway(address _monethaVault, address _orderProcessor) public 
        Restricted(_orderProcessor)
    {
        require(_monethaVault != 0x0);
        monethaVault = _monethaVault;
    }
    
    /**
     *  acceptPayment accept payment from PaymentAcceptor, forwards it to merchant's wallet
     *      and collects Monetha fee.
     *  @param _merchantWallet address of merchant's wallet for fund transfer
     */
    function acceptPayment(address _merchantWallet) external payable onlyProcessor {
        require(_merchantWallet != 0x0);

        uint merchantIncome = msg.value - (FEE_PERMILLE * msg.value / 1000);
        uint monethaIncome = msg.value - merchantIncome;

        _merchantWallet.transfer(merchantIncome);
        monethaVault.transfer(monethaIncome);

        PaymentProcessed(_merchantWallet, merchantIncome, monethaIncome);
    }

    /**
     *  changeMonethaVault allows owner to change address of Monetha Vault.
     *  @param newVault New address of Monetha Vault
     */
    function changeMonethaVault(address newVault) external onlyOwner {
        monethaVault = newVault;
    }
}
