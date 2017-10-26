pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract MonethaGateway is Contactable, Destructible {
    
    string constant VERSION = "1.0";
    uint8 public constant FEE_PROMILLE = 15;
    
    address public monethaVault;
    address public orderProcessor;

    event PaymentProcessed(address merchantWallet, uint merchantIncome, uint monethaIncome);

    function MonethaGateway(address _monethaVault, address _orderProcessor) public {
        require(_monethaVault != 0x0);
        require(_orderProcessor != 0x0);
        
        monethaVault = _monethaVault;
        orderProcessor = _orderProcessor;
    }

    function acceptPayment(address _merchantWallet) external payable {
        require(_merchantWallet != 0x0);
        require(tx.origin == orderProcessor);

        uint merchantIncome = msg.value * (1 - FEE_PROMILLE / 1000);
        uint monethaIncome = msg.value - merchantIncome;

        _merchantWallet.transfer(merchantIncome);
        monethaVault.transfer(monethaIncome);

        PaymentProcessed(_merchantWallet, merchantIncome, monethaIncome);
    }

    function changeMonethaVault(address newVault) external onlyOwner {
        monethaVault = newVault;
    }

    function changeOrderProcessor(address newOrderProcessor) external onlyOwner {
        orderProcessor = newOrderProcessor;
    }
}
