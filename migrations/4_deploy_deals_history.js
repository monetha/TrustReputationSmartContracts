const MerchantDealsHistory = artifacts.require("./MerchantDealsHistory.sol");

module.exports = function(deployer, network, accounts) {
  const processor = accounts[1]
  deployer.deploy(MerchantDealsHistory, "merchantId", processor);
};
