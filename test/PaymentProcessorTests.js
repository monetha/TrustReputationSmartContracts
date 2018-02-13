const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')())
chai.use(require('chai-as-promised'))
chai.should()

const PaymentProcessor = artifacts.require("PaymentProcessor")
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory")
const MonethaGateway = artifacts.require("MonethaGateway")
const MerchantWallet = artifacts.require("MerchantWallet")

contract('PaymentProcessor', function (accounts) {

    const State = {
        Null: 0,
        Created: 1,
        Paid: 2,
        Finalized: 3,
        Refunding: 4,
        Refunded: 5,
        Cancelled: 6
    }

    const OWNER = accounts[0]
    const PROCESSOR = accounts[1]
    const CLIENT = accounts[2]
    const ADMIN = accounts[3]
    const GATEWAY_2 = accounts[4]
    const UNKNOWN = accounts[5]
    const ORIGIN = accounts[6]
    const ACCEPTOR = accounts[7]
    const VAULT = accounts[8]
    const MERCHANT = accounts[9]
    const PRICE = 1000
    const FEE = 15
    const ORDER_ID = 123

    let processor, gateway, wallet, history

    before(async () => {
        gateway = await MonethaGateway.new(VAULT, ADMIN)
        wallet = await MerchantWallet.new(MERCHANT, "merchantId")
        history = await MerchantDealsHistory.new("merchantId")

        processor = await PaymentProcessor.new(
            "merchantId",
            history.address,
            gateway.address,
            wallet.address
        )

        await gateway.setMonethaAddress(processor.address, true, { from: ADMIN })
        await wallet.setMonethaAddress(processor.address, true)
        await history.setMonethaAddress(processor.address, true)
    })

    it('should set Monetha address correctly', async () => {
        await processor.setMonethaAddress(PROCESSOR, true, { from: OWNER })

        const res = await processor.isMonethaAddress(PROCESSOR)
        res.should.be.true
    })

    it('should add order correctly', async () => {
        await processor.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, FEE, { from: PROCESSOR })

        const order = await processor.orders(ORDER_ID)
        new BigNumber(order[0]).should.bignumber.equal(State.Created)
        new BigNumber(order[1]).should.bignumber.equal(PRICE)
        order[3].should.equal(ACCEPTOR)
        order[4].should.equal(ORIGIN)
    })

    it('should accept secure payment correctly', async () => {
        const order = await processor.orders(ORDER_ID)

        await processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        const balance = new BigNumber(web3.eth.getBalance(processor.address))
        balance.should.bignumber.equal(PRICE)

        await checkState(processor, ORDER_ID, State.Paid)
    })

    it('should refund payment correctly', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        const result = await processor.refundPayment(
            ORDER_ID,
            clientReputation,
            merchantReputation,
            0x1234,
            "refundig from tests",
            { from: PROCESSOR }
        )

        await checkReputation(
            wallet,
            clientReputation,
            merchantReputation
        )
        await checkState(processor, ORDER_ID, State.Refunding)

        const order = await processor.orders(ORDER_ID)
    })

    it('should withdraw refund correctly', async () => {
        const clientBalance1 = new BigNumber(web3.eth.getBalance(ORIGIN))
        const processorBalance1 = new BigNumber(web3.eth.getBalance(processor.address))

        await processor.withdrawRefund(ORDER_ID, { from: UNKNOWN })

        const clientBalance2 = new BigNumber(web3.eth.getBalance(ORIGIN))
        const processorBalance2 = new BigNumber(web3.eth.getBalance(processor.address))

        processorBalance2.minus(processorBalance1).should.bignumber.equal(-PRICE)
        clientBalance2.minus(clientBalance1).should.bignumber.equal(PRICE)

        await checkState(processor, ORDER_ID, State.Refunded)
    })

    it('should set Monetha gateway correctly', async () => {
        await processor.setMonethaGateway(GATEWAY_2, { from: OWNER })

        const gateway = await processor.monethaGateway()
        gateway.should.equal(GATEWAY_2)
    })

    it('should cancel order correctly', async () => {
        const contracts = await setupNewWithOrder()

        await contracts.processor.cancelOrder(ORDER_ID, 1234, 1234, 0, "cancel from test", { from: PROCESSOR })

        const order = await contracts.processor.orders(ORDER_ID)
        await checkState(contracts.processor, ORDER_ID, State.Cancelled)
    })

    it('should not allow to send invalid amount of money', () => {
        return setupNewWithOrder()
            .then(a => a.processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE - 1 }))
            .should.be.rejected
    })

    it('should not allow to pay twice', async () => {
        const contracts = await setupNewWithOrder()
        await contracts.processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })
        const res = contracts.processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        return res.should.be.rejected
    })

    it('should process payment correctly', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        const created = await setupNewWithOrder()
        const processor = created.processor

        await processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        const processorBalance1 = new BigNumber(web3.eth.getBalance(processor.address))

        const result = await processor.processPayment(
            ORDER_ID,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        )

        const processorBalance2 = new BigNumber(web3.eth.getBalance(processor.address))
        processorBalance1.minus(processorBalance2).should.bignumber.equal(PRICE)

        await checkReputation(
            created.wallet,
            clientReputation,
            merchantReputation
        )
        await checkState(processor, ORDER_ID, State.Finalized)
    })

    it('should set Merchant Deals History correctly', async () => {
        history = await MerchantDealsHistory.new("merchantId")
        const created = await setupNewWithOrder()

        await created.processor.setMerchantDealsHistory(history.address, { from: OWNER })

        const historyAddress = await created.processor.merchantHistory()
        historyAddress.should.equal(history.address)
    })

    it('should not set Merchant Deals History for different merchant id', async () => {
        const history2 = await MerchantDealsHistory.new("merchant2")

        const created = await setupNewWithOrder("merchant1")

        await created.processor.setMerchantDealsHistory(history2.address, { from: OWNER }).should.be.rejected
    })

    it('should not add order when contract is paused', async () => {
        const ORDER_ID = randomReputation()
        
        await processor.pause({ from: OWNER })

        await processor.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, FEE, { from: PROCESSOR }).should.be.rejected
    })

    async function checkState(processor, orderID, expected) {
        const order = await processor.orders(orderID)
        new BigNumber(order[0]).should.bignumber.equal(expected)
    }

    async function checkReputation(
        merchantWallet,
        expectedClientReputation,
        expectedMerchantReputation
    ) {
        //TODO: add client reputation check, once client wallet will be implemented

        const merchRep = new BigNumber(await merchantWallet.compositeReputation("total"))
        merchRep.should.bignumber.equal(expectedMerchantReputation)
    }


    async function setupNewWithOrder(_merchantId) {
        merchantId = _merchantId || "merchantId";
        let gateway = await MonethaGateway.new(VAULT, ADMIN)
        let wallet = await MerchantWallet.new(MERCHANT, merchantId)
        let history = await MerchantDealsHistory.new(merchantId)

        let processor = await PaymentProcessor.new(
            merchantId,
            history.address,
            gateway.address,
            wallet.address
        )

        await processor.setMonethaAddress(PROCESSOR, true)
        await gateway.setMonethaAddress(processor.address, true, { from: ADMIN })
        await wallet.setMonethaAddress(processor.address, true)
        await history.setMonethaAddress(processor.address, true)

        await processor.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, FEE, { from: PROCESSOR })

        return { processor, wallet }
    }

    function randomReputation() {
        return Math.floor(Math.random() * 100)
    }
})
