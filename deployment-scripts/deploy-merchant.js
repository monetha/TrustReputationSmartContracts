const assert = require('assert');

const Wallet = artifacts.require("MerchantWallet");
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory");
const PaymentProcessor = artifacts.require("PaymentProcessor");
const MonethaGateway = artifacts.require("MonethaGateway");

const config = require("./config.json")
assert(process.argv.length == 5, "Please specify the path to merchant config json file")
const merchantConfig = require(process.argv[4])

module.exports = function (callback) {
  new Promise(async () => {
    try {
      const wallet = await Wallet.new(merchantConfig.merchantAddress, merchantConfig.merchantId)
      console.log("Wallet deployed at " + wallet.address)

      const history = await MerchantDealsHistory.new(merchantConfig.merchantId)
      console.log("MerchantDealsHistory deployed at " + history.address)

      const paymentProcessor = await PaymentProcessor.new(
        merchantConfig.merchantId,
        history.address,
        config.monethaGatewayAddress
      )
      console.log("PaymentProcessor deployed at " + paymentProcessor.address)

      const gateway = MonethaGateway.at(config.monethaGatewayAddress)
      await paymentProcessor.setMonethaAddress(config.processorAddress, true)
      await paymentProcessor.transferOwnership(config.ownerAddress)
      await wallet.setMonethaAddress(paymentProcessor.address, true)
      await wallet.transferOwnership(config.ownerAddress)
      await history.setMonethaAddress(paymentProcessor.address, true)
      await history.transferOwnership(config.ownerAddress)
      await gateway.setMonethaAddress(paymentProcessor.address, true)
      console.log("Monetha addresses configured")

      console.log("Merchant deployment finished.")
      callback()
    }
    catch (reason) {
      callback(reason)
    }
  })
}