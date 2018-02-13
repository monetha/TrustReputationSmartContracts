const assert = require('assert');

const Wallet = artifacts.require("MerchantWallet");
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory");
const PaymentProcessor = artifacts.require("PaymentProcessor");
const PrivatePaymentProcessor = artifacts.require("PrivatePaymentProcessor");
const MonethaGateway = artifacts.require("MonethaGateway");

const config = require("./config.json")
assert(process.argv.length == 6, "Please specify the path to merchant config json file")
const merchantConfig = require(process.argv[5])

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
        config.monethaGatewayAddress,
        wallet.address
      )
      console.log("PaymentProcessor deployed at " + paymentProcessor.address)

      const privatePaymentProcessor = await PrivatePaymentProcessor.new(
        merchantConfig.merchantId,
        config.monethaGatewayAddress,
        wallet.address
      )
      console.log("PrivatePaymentProcessor deployed at " + privatePaymentProcessor.address)

      const gateway = MonethaGateway.at(config.monethaGatewayAddress)
      await paymentProcessor.setMonethaAddress(config.processingAddress, true)
      await paymentProcessor.transferOwnership(config.ownerAddress)
      await privatePaymentProcessor.setMonethaAddress(config.processingAddress, true)
      await privatePaymentProcessor.transferOwnership(config.ownerAddress)
      await wallet.setMonethaAddress(paymentProcessor.address, true)
      await wallet.transferOwnership(config.ownerAddress)
      await history.setMonethaAddress(paymentProcessor.address, true)
      await history.transferOwnership(config.ownerAddress)
      await gateway.setMonethaAddress(paymentProcessor.address, true, {from: config.processingAddress})
      await gateway.setMonethaAddress(privatePaymentProcessor.address, true, {from: config.processingAddress})
      console.log("Monetha addresses configured")

      console.log("Merchant deployment finished.")
      callback()
    }
    catch (reason) {
      callback(reason)
    }
  })
}