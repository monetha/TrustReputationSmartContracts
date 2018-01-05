const utils = require('./utils.js')
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
    const PROCESSOR_2 = accounts[3]
    const GATEWAY_2 = accounts[4]
    const UNKNOWN = accounts[5]
    const ORIGIN = accounts[6]
    const ACCEPTOR = accounts[7]
    const HISTORY_ADDRESS  = "0x8bfd2565f9eda18ec80eac54bf39c2e65e4035d6" //accounts[8]
    const PRICE = 1000
    const ORDER_ID = 123

    let processor

    before(async () => {
        processor = await PaymentProcessor.new(
            "merchantId",
            MerchantWallet.address,
            MonethaGateway.address,
            PROCESSOR_2
        )
    })

    it('should set processor correctly', async () => {
        await processor.setProcessor(PROCESSOR, { from: OWNER })

        const newProcessor = await processor.processor()
        newProcessor.should.equal(PROCESSOR)
    })


    it('should add order correctly', async () => {
        const CREATION_TIME = Math.floor(Date.now())
        await processor.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, CREATION_TIME, { from: PROCESSOR })

        const order = await processor.orders(ORDER_ID)
        new BigNumber(order[0]).should.bignumber.equal(State.Created)
        new BigNumber(order[1]).should.bignumber.equal(PRICE)
        order[3].should.equal(ACCEPTOR)
        order[4].should.equal(ORIGIN)
    })

    it('should not allow to cancel order with different merchant id', async () => {

        history1 = await MerchantDealsHistory.new("diff-merchantId", PROCESSOR)
        processor1 = await setupNewWithOrder("diff-merchantId", history1.address)

        await processor1.cancelOrder(ORDER_ID, MerchantWallet.address, 1234, 1234, 0, "cancel from test", { from: PROCESSOR })
        .should.be.rejected
    })

    it('should cancel order correctly', async () => {
        processor = await setupNewWithOrder()

        await processor.cancelOrder(ORDER_ID, MerchantWallet.address, 1234, 1234, 0, "cancel from test", { from: PROCESSOR })

        const order = await processor.orders(ORDER_ID)
        await checkState(processor, ORDER_ID, State.Cancelled)
    })

    it('should not allow to send invalid amount of money', () => {
        return setupNewWithOrder()
            .then(a => a.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE - 1 }))
            .should.be.rejected
    })

    it('should not allow to pay twice', () => {
        return setupNewWithOrder()
            .then(a => a.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE }))
            .then(a => a.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE }))
            .should.be.rejected
    })

    it('should not allow to pay after order expired', () => {
        return setupNewWithOrder()
            .then(() => utils.increaseTime(LIFETIME + 1))
            .then(a => a.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE }))
            .should.be.rejected
    })

    it('should accept secure payment correctly', async () => {
        processor = await setupNewWithOrder()

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
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            "refundig from tests",
            { from: PROCESSOR }
        )

        await checkReputation(
            await MerchantWallet.deployed(),
            result,
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

    it('should process payment correctly', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        processor = await setupNewWithOrder()
        await processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        const processorBalance1 = new BigNumber(web3.eth.getBalance(processor.address))

        const result = await processor.processPayment(
            ORDER_ID,
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        )

        const processorBalance2 = new BigNumber(web3.eth.getBalance(processor.address))
        processorBalance1.minus(processorBalance2).should.bignumber.equal(PRICE)

        await checkReputation(
            await MerchantWallet.deployed(),
            result,
            clientReputation,
            merchantReputation
        )
        await checkState(processor, ORDER_ID, State.Finalized)
    })

    it('should not process payment for different merchant id', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        history1 = await MerchantDealsHistory.new("diff-merchantId", PROCESSOR)
        processor1 = await setupNewWithOrder("diff-merchantId", history1.address)

        await processor1.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        await processor1.processPayment(
            ORDER_ID,
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        ).should.be.rejected
    })

    it('should set Monetha gateway correctly', async () => {
        await processor.setMonethaGateway(GATEWAY_2, { from: OWNER })

        const gateway = await processor.monethaGateway()
        gateway.should.equal(GATEWAY_2)
    })

    it('should not allow to refund payment for different merchant Id', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        history1 = await MerchantDealsHistory.new("diff-merchantId", PROCESSOR)
        processor1 = await setupNewWithOrder("diff-merchantId", history1.address)

        await processor1.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })

        const result = await processor1.refundPayment(
            ORDER_ID,
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            "refundig from tests",
            { from: PROCESSOR }
        ).should.be.rejected
    })

    it('should set Merchant Deals History correctly', async () => {
        history = await MerchantDealsHistory.new("merchantId", PROCESSOR)
        processor = await setupNewWithOrder()

        await processor.setMerchantDealsHistory(history.address, { from: OWNER })
        
        const historyAddress = await processor.merchantHistory()
        historyAddress.should.equal(history.address)
    })

    it('should not set Merchant Deals History for different merchant id', async () => {
        history1 = await MerchantDealsHistory.new("merchant1", PROCESSOR)
        history2 = await MerchantDealsHistory.new("merchant2", PROCESSOR)

        processor1 = await setupNewWithOrder("merchant1", history1.address)

        await processor1.setMerchantDealsHistory(history2.address, { from: OWNER }).should.be.rejected
    })

    it('should not add order when contract is paused', async () => {
        const CREATION_TIME = Math.floor(Date.now())
        const ORDER_ID = randomReputation()
        await processor.pause({from:OWNER})

        await processor.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, CREATION_TIME, { from: PROCESSOR }).should.be.rejected
    })

    async function checkState(processor, orderID, expected) {
        const order = await processor.orders(orderID)
        new BigNumber(order[0]).should.bignumber.equal(expected)
    }

    async function checkReputation(
        merchantWallet,
        result,
        expectedClientReputation,
        expectedMerchantReputation
    ) {
        //TODO: add client reputation check, once client wallet will be implemented

        const merchRep = new BigNumber(await merchantWallet.compositeReputation("total"))
        merchRep.should.bignumber.equal(expectedMerchantReputation)
    }

    async function setupNewWithOrder(_merchantId, _address) {
        merchantId = _merchantId || "merchantId";
        address = _address || MerchantDealsHistory.address;
        const CREATION_TIME = Math.floor(Date.now())
        const res = await PaymentProcessor.new(
            merchantId,
            address,
            MonethaGateway.address,
            PROCESSOR
        )

        await res.addOrder(ORDER_ID, PRICE, ACCEPTOR, ORIGIN, CREATION_TIME, { from: PROCESSOR })

        return res
    }

    function randomReputation(){
        return Math.floor(Math.random() * 100)
    }
})
