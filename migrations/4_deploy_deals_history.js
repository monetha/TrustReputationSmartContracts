const MerchantDealsHistory = artifacts.require("./MerchantDealsHistory.sol");

module.exports = function (deployer, network, accounts) {
  let processor
  if (network == "kovan") {
    processor = "0x001D51cDC8f4B378e136642DdB95Dfc4fF6a4B72"
  }
  else {
    processor = accounts[1]
  }
  deployer.deploy(MerchantDealsHistory, "merchantId", processor);
};
