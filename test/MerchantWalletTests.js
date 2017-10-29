const BigNumber = require('bignumber.js')
const chai = require('chai')
chai.use(require('chai-bignumber')());
chai.use(require('chai-as-promised'))
chai.should()

const Wallet = artifacts.require("./MerchantWallet.sol")

contract('MerchantWallet', function (accounts) {

    const OWNER = accounts[0]
    const MERCHANT = accounts[1]
    const MERCHANT2 = accounts[2]
    const UNKNOWN = accounts[3]
    const PROCESSOR = accounts[4]

    let wallet

    before(async () => {
        wallet = await Wallet.new(MERCHANT, "merchantId", PROCESSOR)
    });

    it('should set profile correctly', async () => {
        await wallet.setProfile("name", "Merchant", { from: OWNER })
        const res = await wallet.profile("name")

        res.should.equal("Merchant")
    })

    it('should set paymentSettings correctly', async () => {
        await wallet.setPaymentSettings("fee", "0.005", { from: OWNER })
        const res = await wallet.paymentSettings("fee")

        res.should.equal("0.005")
    })

    it('should set compositeReputation correctly', async () => {
        await wallet.setCompositeReputation("Delivery", 5, { from: PROCESSOR })
        const res = new BigNumber(await wallet.compositeReputation("Delivery"))

        res.should.bignumber.equal(5)
    })

    it('should not allow to set state by other accounts', () => {
        const promises = [
            wallet.setProfile("name", "Merchant", { from: UNKNOWN }).should.be.rejected,
            wallet.setPaymentSettings("fee", "0.005", { from: UNKNOWN }).should.be.rejected,
            wallet.setCompositeReputation("Delivery", 5, { from: UNKNOWN }).should.be.rejected
        ]
        
        return Promise.all(promises)
    })

    it('should change merchant account correctly', async () => {
        await wallet.changeMerchantAccount(MERCHANT2, { from: MERCHANT })
        const res = await wallet.merchantAccount()

        res.should.equal(MERCHANT2)
    })

    it('should not allow to change merchant account by other accounts', () => {
        return wallet.changeMerchantAccount(MERCHANT2, { from: UNKNOWN }).should.be.rejected
    })

    it('should withdraw money correctly', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        const balance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        await wallet.withdrawTo(MERCHANT, amount, { from: MERCHANT2 })
        const balance2 = new BigNumber(web3.eth.getBalance(MERCHANT))
        
        balance2.should.bignumber.equal(balance1.plus(amount))
    })

    it('should not allow to withdraw by other accounts', () => {
        return wallet.withdrawTo(MERCHANT, { from: UNKNOWN }).should.be.rejected
    })

    it('should not allow to withdraw when contract is paused', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.pause({from:OWNER})

        return wallet.withdrawTo(MERCHANT, amount, { from: MERCHANT2 }).should.be.rejected
    })

    it('should not allow to change merchant account by other accounts', () => {
        return wallet.changeMerchantAccount(MERCHANT, { from: MERCHANT2 }).should.be.rejected
    })
});
