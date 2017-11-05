const Wallet = artifacts.require("./MerchantWallet.sol");

module.exports = function(deployer, network, accounts) {
  const processor = accounts[1]
  const merchant = accounts[2]
  deployer.deploy(Wallet, merchant, "merchantId", processor);
};
