const utils = require('../utils.js')
const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')())
chai.use(require('chai-as-promised'))
chai.should()

const PaymentProcessor = artifacts.require("PaymentProcessor")
const MerchantDealsHistory = artifacts.require("MerchantDealsHistory")
const MonethaGateway = artifacts.require("MonethaGateway")
const MerchantWallet = artifacts.require("MerchantWallet")

contract('TEST', function (accounts) {

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
    const DEALHASH = 0x1234


    before(async () => {
    })


    describe('Payment flow. User is able to pay for his order', function() {
    
    for (i = 0; i < 1; i++) {
        const PRICE = randomOrderId()
        const ORDER_ID = randomOrderId()
        const MERCHANT_ID = "merchantId"

        it('should set payment processor correctly', async () => {
            processor = await PaymentProcessor.new(
                MERCHANT_ID,
                MerchantDealsHistory.address,
                MonethaGateway.address,
                PROCESSOR_2
            )
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

/*
        it('after', async () => {
            const order = await processor.orders(ORDER_ID)
           // console.log("merchantwallet " + JSON.stringify(merchantwallet))
            console.log("MERCHANT_ID = " + MERCHANT_ID)
            console.log("PRICE       = " + PRICE)
            console.log("order id    = " + ORDER_ID)
            console.log("order state = " + order[0])
        })
        */

        it('should accept secure payment correctly', async () => {
            const order = await processor.orders(ORDER_ID)

            await processor.securePay(ORDER_ID, { from: ACCEPTOR, value: PRICE })
            
            const balance = new BigNumber(web3.eth.getBalance(processor.address))
            balance.should.bignumber.equal(PRICE)
            
            await checkState(processor, ORDER_ID, State.Paid)
        })
/*
        it('after', async () => {
            const order = await processor.orders(ORDER_ID)
            console.log("order id    = " + ORDER_ID)
            console.log("order state = " + order[0])
        })
*/

        it('should process payment correctly', async () => {
            const clientReputation = randomReputation()
            const merchantReputation = randomReputation()
    
            const processorBalance1 = new BigNumber(web3.eth.getBalance(processor.address))
    
            const result = await processor.processPayment(
                ORDER_ID,
                MerchantWallet.address,
                clientReputation,
                merchantReputation,
                DEALHASH,
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
    
        it('should set Monetha gateway correctly', async () => {
            await processor.setMonethaGateway(GATEWAY_2, { from: OWNER })
    
            const gateway = await processor.monethaGateway()
            gateway.should.equal(GATEWAY_2)
        })
    }
    });

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
        const merchRep = new BigNumber(await merchantWallet.compositeReputation("total"))
        merchRep.should.bignumber.equal(expectedMerchantReputation)
    }

    function randomReputation(){
        return Math.floor(Math.random() * 100)
    }

    function randomOrderId(){
        return Math.floor(Math.random() * 100000)
    }
})
