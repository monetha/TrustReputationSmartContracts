const Wallet = artifacts.require("MerchantWallet");
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory");
const PaymentProcessor = artifacts.require("PaymentProcessor");

const config = require("./config.json")

module.exports = function (callback) {
  new Promise(async () => {
    try {
      const wallet = await Wallet.new(config.merchantAddress, config.merchantId, config.processorAddress)
      await wallet.transferOwnership(config.ownerAddress)
      console.log("Wallet deployed at " + wallet.address)

      const history = await MerchantDealsHistory.new(config.merchantId, config.processorAddress)
      await history.transferOwnership(config.ownerAddress)
      console.log("MerchantDealsHistory deployed at " + history.address)

      const paymentProcessor = await PaymentProcessor.new(
        config.merchantId,
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