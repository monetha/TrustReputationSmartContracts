const PaymentProcessor = artifacts.require("PaymentProcessor");
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory");
const MonethaGateway = artifacts.require("MonethaGateway");

module.exports = function(deployer, network, accounts) {
  const processor = accounts[1]
  deployer.deploy(
    PaymentProcessor,
    "merchantId",
    MerchantDealsHistory.address,
    MonethaGateway.address,
    processor
  );
};
