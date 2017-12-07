const MonethaGateway = artifacts.require("./MonethaGateway.sol");

module.exports = function (deployer, network, accounts) {
  let processor, vault
  if (network == "kovan") {
    processor = "0x001D51cDC8f4B378e136642DdB95Dfc4fF6a4B72"
    vault = "0x00861d9C49d274A6863B45850e0F01C4874DF341"
  }
  else {
    processor = accounts[1]
    vault = accounts[2]
  }
  deployer.deploy(MonethaGateway, vault, processor);
};
