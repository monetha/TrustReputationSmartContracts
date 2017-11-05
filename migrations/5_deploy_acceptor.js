const PaymentAcceptor = artifacts.require("./PaymentAcceptor.sol");
const MerchantDealsHistory = artifacts.require("./MerchantDealsHistory.sol");
const MonethaGateway = artifacts.require("./MonethaGateway.sol");

module.exports = function(deployer, network, accounts) {
  const processor = accounts[1]
  deployer.deploy(
    PaymentAcceptor,
    "merchantId",
    MerchantDealsHistory.address,
    MonethaGateway.address,
    15 * 60,
    processor
  );
};
