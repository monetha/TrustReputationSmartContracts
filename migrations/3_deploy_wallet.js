const Wallet = artifacts.require("./MerchantWallet.sol");

module.exports = function (deployer, network, accounts) {
  let processor, merchant
  if (network == "kovan") {
    processor = "0x001D51cDC8f4B378e136642DdB95Dfc4fF6a4B72"
    merchant = "0x003f57bB9328f07eb40C3b1B19ed14e879DAB0f4"
  }
  else {
    processor = accounts[1]
    merchant = accounts[2]
  }
  deployer.deploy(Wallet, merchant, "merchantId", processor);
};
