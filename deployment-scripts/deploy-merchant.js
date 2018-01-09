const assert = require('assert');

const Wallet = artifacts.require("MerchantWallet");
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory");
const PaymentProcessor = artifacts.require("PaymentProcessor");

const config = require("./config.json")
assert(process.argv.length == 5, "Please specify the path to merchant config json file")
const merchantConfig = require(process.argv[4])

module.exports = function (callback) {
  new Promise(async () => {
    try {
      const wallet = await Wallet.new(merchantConfig.merchantAddress, merchantConfig.merchantId, config.processorAddress)
      await wallet.transferOwnership(config.ownerAddress)
      console.log("Wallet deployed at " + wallet.address)

      const history = await MerchantDealsHistory.new(merchantConfig.merchantId, config.processorAddress)
      await history.transferOwnership(config.ownerAddress)
      console.log("MerchantDealsHistory deployed at " + history.address)

      const paymentProcessor = await PaymentProcessor.new(
        merchantConfig.merchantId,
        history.address,
        config.monethaGatewayAddress,
        config.processorAddress
      )
      await paymentProcessor.transferOwnership(config.ownerAddress)
      console.log("PaymentProcessor deployed at " + paymentProcessor.address)

      console.log("Merchant deployment finished.")
      callback()
    }
    catch (reason) {
      callback(reason)
    }
  })
}