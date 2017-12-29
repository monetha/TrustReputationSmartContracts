const MonethaGateway = artifacts.require("MonethaGateway");

const config = require("./config.json")

module.exports = function (callback) {
  new Promise(async () => {
    try {
      const gateway = await MonethaGateway.new(config.vaultAddress, config.processorAddress)
      await gateway.transferOwnership(config.ownerAddress)
      console.log("MonethaGateway deployed at " + gateway.address)

      console.log("Infrastructure deployment finished.")
      callback()
    }
    catch (reason) {
      callback(reason)
    }
  })
}