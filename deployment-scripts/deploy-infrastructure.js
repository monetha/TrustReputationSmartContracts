const MonethaGateway = artifacts.require("MonethaGateway");

const config = require("./config.json")

module.exports = function (callback) {
  new Promise(async () => {
    try {
      const gateway = await MonethaGateway.new(config.vaultAddress)
      //await gateway.transferOwnership(config.ownerAddress)  // we need to call setMonethaAddress in deploy-merchant.js
      console.log("MonethaGateway deployed at " + gateway.address)

      console.log("Infrastructure deployment finished.")
      callback()
    }
    catch (reason) {
      callback(reason)
    }
  })
}