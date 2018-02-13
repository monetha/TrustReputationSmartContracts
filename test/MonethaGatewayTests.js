const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')());
chai.use(require('chai-as-promised'))
chai.should()

const MonethaGateway = artifacts.require("./MonethaGateway.sol")

contract('MonethaGateway', function (accounts) {

    const OWNER = accounts[0]
    const VAULT = accounts[1]
    const MERCHANT = accounts[2]
    const PAYMENT_PROCESSOR_CONTRACT = accounts[3]
    const ADMIN = accounts[4]

    let gateway

    before(async () => {
        gateway = await MonethaGateway.new(VAULT, ADMIN)
        await gateway.setMonethaAddress(PAYMENT_PROCESSOR_CONTRACT, true, {from: ADMIN})
    });

    it('should accept payment correctly', async () => {
        const value = new BigNumber('1e9')
        const feeValue = new BigNumber(await gateway.FEE_PERMILLE()).mul(value).div(1000)

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.acceptPayment(MERCHANT, feeValue, { value: value, from: PAYMENT_PROCESSOR_CONTRACT })

        const merchantBalance2 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance2 = new BigNumber(web3.eth.getBalance(VAULT))

        const deltaMerchant = merchantBalance2.minus(merchantBalance1)
        const deltaVault = vaultBalance2.minus(vaultBalance1)
        
        deltaMerchant.should.bignumber.equal(value.sub(feeValue))
        deltaVault.should.bignumber.equal(feeValue)
    })

    it('should accept payment with zero fee correctly', async () => {
        const value = new BigNumber('1e9')
        const feeValue = new BigNumber('0')

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.acceptPayment(MERCHANT, feeValue, { value: value, from: PAYMENT_PROCESSOR_CONTRACT })

        const merchantBalance2 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance2 = new BigNumber(web3.eth.getBalance(VAULT))

        const deltaMerchant = merchantBalance2.minus(merchantBalance1)
        const deltaVault = vaultBalance2.minus(vaultBalance1)

        deltaMerchant.should.bignumber.equal(value.sub(feeValue))
        deltaVault.should.bignumber.equal(feeValue)
    })

    it('should not accept payment accept payment with high fee', async () => {
        const value = new BigNumber('1e9')
        const feeValue = new BigNumber(await gateway.FEE_PERMILLE()).mul(value).div(1000).add(1)

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.acceptPayment(MERCHANT, feeValue, { value: value, from: PAYMENT_PROCESSOR_CONTRACT }).should.be.rejected
    })

    it('should not accept payment when contract is paused', async () => {
        const value = new BigNumber('1e9')
        const feeValue = new BigNumber(await gateway.FEE_PERMILLE()).mul(value).div(1000)

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.pause({from:OWNER})

        await gateway.acceptPayment(MERCHANT, feeValue, { value: value, from: PAYMENT_PROCESSOR_CONTRACT }).should.be.rejected
    })
});
