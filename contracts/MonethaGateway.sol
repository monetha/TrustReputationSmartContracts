pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";
import "./Restricted.sol";


contract MonethaGateway is Contactable, Destructible, Restricted {
    
    string constant VERSION = "1.0";
    uint8 public constant FEE_PROMILLE = 15;
    
    address public monethaVault;

    event PaymentProcessed(address merchantWallet, uint merchantIncome, uint monethaIncome);

    function MonethaGateway(address _monethaVault, address _orderProcessor) public 
        Restricted(_orderProcessor)
    {
        require(_monethaVault != 0x0);
        monethaVault = _monethaVault;
    }

    function acceptPayment(address _merchantWallet) external payable onlyProcessor {
        require(_merchantWallet != 0x0);

        uint merchantIncome = msg.value - (FEE_PROMILLE * msg.value / 1000);
        uint monethaIncome = msg.value - merchantIncome;

        _merchantWallet.transfer(merchantIncome);
        monethaVault.transfer(monethaIncome);

        PaymentProcessed(_merchantWallet, merchantIncome, monethaIncome);
    }

    function changeMonethaVault(address newVault) external onlyOwner {
        monethaVault = newVault;
    }
}
