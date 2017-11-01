const utils = require('./utils.js')
const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')())
chai.use(require('chai-as-promised'))
chai.should()

const PaymentAcceptor = artifacts.require("./PaymentAcceptor.sol")
const MerchantDealsHistory = artifacts.require("./MerchantDealsHistory.sol")
const MonethaGateway = artifacts.require("./MonethaGateway.sol")
const MerchantWallet = artifacts.require("./MerchantWallet.sol")

contract('PaymentAcceptor', function (accounts) {

    const State = {
        Inactive: 0,
        MerchantAssigned: 1,
        OrderAssigned: 2,
        Paid: 3,
        Refunding: 4
    }

    const OWNER = accounts[0]
    const PROCESSOR = accounts[1]
    const CLIENT = accounts[2]
    const PROCESSOR_2 = accounts[3]
    const GATEWAY_2 = accounts[4]
    const UNKNOWN = accounts[5]
    const LIFETIME = 15 * 60
    const PRICE = 1000

    let acceptor

    before(async () => {
        acceptor = await PaymentAcceptor.new(
            "merchantId",
            "0x0",
            MonethaGateway.address,
            LIFETIME,
            PROCESSOR_2
        )
    })

    it('should set processor correctly', async () => {
        await acceptor.setProcessor(PROCESSOR, { from: OWNER })

        const newProcessor = await acceptor.processor()
        newProcessor.should.equal(PROCESSOR)
    })

    it('should unassign merchant correctly', async () => {
        await checkState(acceptor, State.MerchantAssigned)

        await acceptor.unassignMerchant({ from: OWNER })

        await checkState(acceptor, State.Inactive)
    })

    it('should set merchant correctly', async () => {
        await acceptor.setMerchant("merchantId2", MerchantDealsHistory.address, { from: OWNER })

        const merchant = await acceptor.merchantId()
        const history = await acceptor.merchantHistory()
        merchant.should.equal("merchantId2")
        history.should.equal(MerchantDealsHistory.address)

        await checkState(acceptor, State.MerchantAssigned)
    })

    it('should assign order correctly', async () => {
        await acceptor.assignOrder(123, PRICE, { from: PROCESSOR })

        const orderId = new BigNumber(await acceptor.orderId())
        const price = new BigNumber(await acceptor.price())
        orderId.should.bignumber.equal(123)
        price.should.bignumber.equal(PRICE)

        await checkState(acceptor, State.OrderAssigned)
    })

    it('should not allow to cancel before order lifetime', () => {
        const future = acceptor.cancelOrder(
            MerchantWallet.address,
            1,
            2,
            0x1234,
            { from: PROCESSOR }
        )

        return future.should.be.rejected
    })

    it('should cancel order correctly after order lifetime', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        await utils.increaseTime(LIFETIME + 1)

        const result = await acceptor.cancelOrder(
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        )
        
        await checkReputation(
            await MerchantWallet.deployed(),
            result,
            clientReputation,
            merchantReputation
        )
        await checkState(acceptor, State.MerchantAssigned)
    })

    it('should not allow to send invalid amount of money', () => {
        return setupNewWithOrder()
            .then(a => a.securePay({ from: CLIENT, value: PRICE - 1 }))
            .should.be.rejected
    })

    it('should not allow to pay twice', () => {
        return setupNewWithOrder()
            .then(a => a.securePay({ from: CLIENT, value: PRICE }))
            .then(a => a.securePay({ from: CLIENT, value: PRICE }))
            .should.be.rejected
    })

    it('should not allow to pay after order expired', () => {
        return setupNewWithOrder()
            .then(() => utils.increaseTime(LIFETIME + 1))
            .then(a => a.securePay({ from: CLIENT, value: PRICE }))
            .should.be.rejected
    })

    it('should accept secure payment correctly', async () => {
        acceptor = await setupNewWithOrder()

        await acceptor.securePay({ from: CLIENT, value: PRICE })

        const client = await acceptor.client()
        client.should.equal(CLIENT)

        const balance = new BigNumber(web3.eth.getBalance(acceptor.address))
        balance.should.bignumber.equal(PRICE)

        await checkState(acceptor, State.Paid)
    })

    it('should accept payment correctly', async () => {
        acceptor = await setupNewWithOrder()

        await acceptor.sendTransaction({ from: CLIENT, value: PRICE })

        const balance = new BigNumber(web3.eth.getBalance(acceptor.address))
        balance.should.bignumber.equal(PRICE)

        await checkState(acceptor, State.OrderAssigned)
    })

    it('should set client correctly', async () => {
        await acceptor.setClient(CLIENT, { from: PROCESSOR })

        const client = await acceptor.client()
        client.should.equal(CLIENT)

        await checkState(acceptor, State.Paid)
    })

    it('should refund payment correctly', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        const result = await acceptor.refundPayment(
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        )

        const balance = new BigNumber(web3.eth.getBalance(acceptor.address))
        balance.should.bignumber.equal(PRICE)

        await checkReputation(
            await MerchantWallet.deployed(),
            result,
            clientReputation,
            merchantReputation
        )
        await checkState(acceptor, State.Refunding)
    })

    it('should withdraw refund correctly', async () => {
        const clientBalance1 = new BigNumber(web3.eth.getBalance(CLIENT))

        await acceptor.withdrawRefund({ from: UNKNOWN })

        const clientBalance2 = new BigNumber(web3.eth.getBalance(CLIENT))
        const delta = clientBalance2.minus(clientBalance1)
        const acceptorBalance = new BigNumber(web3.eth.getBalance(acceptor.address))

        delta.should.bignumber.equal(PRICE)
        acceptorBalance.should.bignumber.equal(0)

        await checkState(acceptor, State.MerchantAssigned)
    })

    it('should process payment correctly', async () => {
        const clientReputation = randomReputation()
        const merchantReputation = randomReputation()

        acceptor = await setupNewWithOrder()
        await acceptor.securePay({ from: CLIENT, value: PRICE })

        const result = await acceptor.processPayment(
            MerchantWallet.address,
            clientReputation,
            merchantReputation,
            0x1234,
            { from: PROCESSOR }
        )

        const acceptorBalance = new BigNumber(web3.eth.getBalance(acceptor.address))
        acceptorBalance.should.bignumber.equal(0)

        await checkReputation(
            await MerchantWallet.deployed(),
            result,
            clientReputation,
            merchantReputation
        )
        await checkState(acceptor, State.MerchantAssigned)
    })

    it('should set Monetha gateway correctly', async () => {
        await acceptor.setMonethaGateway(GATEWAY_2, { from: OWNER })

        const gateway = await acceptor.monethaGateway()
        gateway.should.equal(GATEWAY_2)
    })

    it('should set lifetime correctly', async () => {
        await acceptor.setLifetime(1)

        const lifetime = new BigNumber(await acceptor.lifetime())
        lifetime.should.bignumber.equal(1)
    })

    async function checkState(acceptor, expected) {
        const current = new BigNumber(await acceptor.state())
        current.should.bignumber.equal(expected)
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

    async function setupNewWithOrder() {
        const res = await PaymentAcceptor.new(
            "merchantId",
            MerchantDealsHistory.address,
            MonethaGateway.address,
            LIFETIME,
            PROCESSOR
        )

        await res.assignOrder(123, PRICE, { from: PROCESSOR })

        return res
    }

    function randomReputation(){
        return Math.floor(Math.random() * 100)
    }
})
