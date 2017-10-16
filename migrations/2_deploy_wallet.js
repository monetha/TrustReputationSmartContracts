const Wallet = artifacts.require("./MerchantWallet.sol");

module.exports = function(deployer, network, accounts) {
  const merchant = accounts[1]
  deployer.deploy(Wallet, merchant);
};
