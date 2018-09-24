const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')())
chai.use(require('chai-as-promised'))
chai.should()

const PrivatePaymentProcessor = artifacts.require("PrivatePaymentProcessor")
const MonethaGateway = artifacts.require("MonethaGateway")
const MerchantWallet = artifacts.require("MerchantWallet")

contract('PrivatePaymentProcessor', function (accounts) {

    const OWNER = accounts[0]
    const PROCESSOR = accounts[1]
    const CLIENT = accounts[2]
    let FUND_ADDRESS = accounts[3]
    const GATEWAY_2 = accounts[4]
    const UNKNOWN = accounts[5]
    const ORIGIN = accounts[6]
    const ACCEPTOR = accounts[7]
    const VAULT = accounts[8]
    const MERCHANT = accounts[9]
    
    const PRICE = 1000
    const FEE = 15
    const ORDER_ID = 123

    let processor, gateway, wallet

    before(async () => {
        gateway = await MonethaGateway.new(VAULT, PROCESSOR)
        await gateway.transferOwnership(OWNER)

        let merchantId = "merchantId"

        wallet = await MerchantWallet.new(MERCHANT, merchantId, FUND_ADDRESS)

        processor = await PrivatePaymentProcessor.new(
            merchantId,
            gateway.address,
            wallet.address
        )

        await processor.setMonethaAddress(PROCESSOR, true)
        await processor.transferOwnership(OWNER)
        await wallet.setMonethaAddress(processor.address, true)
        await wallet.transferOwnership(OWNER)
        await gateway.setMonethaAddress(processor.address, true, { from: PROCESSOR })
    })

    it('should indentify processor address as Monetha address', async () => {
        const res = await processor.isMonethaAddress(PROCESSOR)
        res.should.be.true
    })

    it('should not pay for order when monetha fee > 1.5%', async () => {
        const monethaFee = 16
        await processor.payForOrder(ORDER_ID, ORIGIN, monethaFee, { from: ACCEPTOR, value: PRICE }).should.be.rejected
    })

    it('should refund payment correctly', async () => {
        const result = await processor.refundPayment(
            ORDER_ID,
            ORIGIN,
            "refundig from tests",
            { from: PROCESSOR, value: PRICE }
        )
        const withdrawal = await processor.withdrawals(ORDER_ID)

        new BigNumber(withdrawal[0]).should.bignumber.equal(1) // Withdraw State Pending.
        new BigNumber(withdrawal[1]).should.bignumber.equal(PRICE) // Withdraw amount.
        withdrawal[2].should.equal(ORIGIN) // Withdraw clientAddress.
    })

    it('should withdraw refund correctly', async () => {
        const clientBalance1 = new BigNumber(web3.eth.getBalance(ORIGIN))
        const processorBalance1 = new BigNumber(web3.eth.getBalance(processor.address))

        await processor.withdrawRefund(ORDER_ID, { from: UNKNOWN })

        const clientBalance2 = new BigNumber(web3.eth.getBalance(ORIGIN))
        const processorBalance2 = new BigNumber(web3.eth.getBalance(processor.address))

        processorBalance2.minus(processorBalance1).should.bignumber.equal(-PRICE)
        clientBalance2.minus(clientBalance1).should.bignumber.equal(PRICE)
    })

    it('should set Monetha gateway correctly', async () => {
        const oldGateWayAddress = await processor.monethaGateway()
        await processor.setMonethaGateway(GATEWAY_2, { from: OWNER })

        const gateway = await processor.monethaGateway()
        gateway.should.equal(GATEWAY_2)

        await processor.setMonethaGateway(oldGateWayAddress, { from: OWNER })
    })

    it('should not allo to withdraw refund two times', async () => {
        await processor.withdrawRefund(ORDER_ID, { from: UNKNOWN }).should.be.rejected
    })

    it('should pay for order correctly when fund address is present', async () => {
        FUND_ADDRESS = accounts[3]
        const FUND_ADDRESS_BALANCE = new BigNumber(web3.eth.getBalance(FUND_ADDRESS))
        const monethaFee = FEE
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))
        
        await processor.payForOrder(ORDER_ID, ORIGIN, monethaFee, { from: ACCEPTOR, value: PRICE })
        
        const FUND_ADDRESS_BALANCE2 = new BigNumber(web3.eth.getBalance(FUND_ADDRESS))
        const vaultBalance2 = new BigNumber(web3.eth.getBalance(VAULT))
        
        vaultBalance2.minus(vaultBalance1).should.bignumber.equal(monethaFee)
        FUND_ADDRESS_BALANCE2.minus(FUND_ADDRESS_BALANCE).should.bignumber.equal(PRICE - monethaFee)
    })
    
    it('should pay for order correctly when fund address is not present', async () => {
        FUND_ADDRESS = "0x0000000000000000000000000000000000000000"
        gateway = await MonethaGateway.new(VAULT, PROCESSOR)
        await gateway.transferOwnership(OWNER)

        const merchantId = "merchantId"

        wallet = await MerchantWallet.new(MERCHANT, merchantId, FUND_ADDRESS)

        processor = await PrivatePaymentProcessor.new(
            merchantId,
            gateway.address,
            wallet.address
        )

        await processor.setMonethaAddress(PROCESSOR, true)
        await processor.transferOwnership(OWNER)
        await wallet.setMonethaAddress(processor.address, true)
        await wallet.transferOwnership(OWNER)
        await gateway.setMonethaAddress(processor.address, true, { from: PROCESSOR })


        const monethaFee = FEE
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await processor.payForOrder(ORDER_ID, ORIGIN, monethaFee, { from: ACCEPTOR, value: PRICE })

        const vaultBalance2 = new BigNumber(web3.eth.getBalance(VAULT))
        const merchantBalance = new BigNumber(web3.eth.getBalance(wallet.address))

        vaultBalance2.minus(vaultBalance1).should.bignumber.equal(monethaFee)
        merchantBalance.should.bignumber.equal(PRICE - monethaFee)
    })

    it('should not pay for order when price is 0', async () => {
        const monethaFee = 0
        await processor.payForOrder(ORDER_ID, ORIGIN, monethaFee, { from: ACCEPTOR, value: 0 }).should.be.rejected
    })

    it('should not pay for order when order id is 0', async () => {
        const monethaFee = FEE
        await processor.payForOrder(0, ORIGIN, monethaFee, { from: ACCEPTOR, value: PRICE }).should.be.rejected
    })
})
