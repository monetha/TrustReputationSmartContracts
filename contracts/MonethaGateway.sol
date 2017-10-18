pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/ownership/Contactable.sol";


contract MonethaGateway is Contactable, Destructable{

    uint8 public constant FEE_PROMILLE = 15;
    
    address public monethaVault;

    event PaymentProcessed(address merchantWallet, uint merchantIncome, uint monethaIncome);

    function MonethaGateway(address _monethaVault) public {
        require(_monethaVault != 0x0);
        monethaVault = _monethaVault;
    }

    function changeMonethaVault(address newVault) external onlyOwner {
        monethaVault = newVault;
    }

    function acceptPayment(address _merchantWallet) external payable {
        require(_merchantWallet != 0x0);

        uint merchantIncome = msg.value * (1 - FEE_PROMILLE / 1000);
        uint monethaIncome = msg.value - merchantIncome;

        _merchantWallet.transfer(merchantIncome);
        monethaVault.transfer(monethaIncome);

        PaymentProcessed(_merchantWallet, merchantIncome, monethaIncome);
    }
}
