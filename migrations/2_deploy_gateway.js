const MonethaGateway = artifacts.require("./MonethaGateway.sol");

module.exports = function(deployer, network, accounts) {
  const vault = accounts[1]
  const processor = accounts[2]
  deployer.deploy(MonethaGateway, vault, processor);
};
