const MonethaGateway = artifacts.require("./MonethaGateway.sol");

module.exports = function(deployer, network, accounts) {
  const processor = accounts[1]
  const vault = accounts[2]
  deployer.deploy(MonethaGateway, vault, processor);
};
