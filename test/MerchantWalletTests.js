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
    const PAYMENT_PROCESSOR_CONTRACT = accounts[4]
    const SAFE_ACCOUNT = accounts[5]
    const FUND_ADDRESS = accounts[6]
    const FUND_ADDRESS2 = accounts[7]

    let wallet

    before(async () => {
        wallet = await Wallet.new(MERCHANT, "merchantId", FUND_ADDRESS)
        await wallet.setMonethaAddress(PAYMENT_PROCESSOR_CONTRACT, true)
    });

    it('should set profile correctly', async () => {
        await wallet.setProfile("name", "Merchant", "", 0, { from: OWNER })
        const res = await wallet.profile("name")

        res.should.equal("Merchant")
    })

    it('should set profile with reputation correctly', async () => {
        await wallet.setProfile("name", "Merchant", "Total", 5, { from: OWNER })
        const name = await wallet.profile("name")
        const rep = new BigNumber(await wallet.compositeReputation("Total"))

        name.should.equal("Merchant")
        rep.should.bignumber.equal(5)
    })

    it('should set paymentSettings correctly', async () => {
        await wallet.setPaymentSettings("fee", "0.005", { from: OWNER })
        const res = await wallet.paymentSettings("fee")

        res.should.equal("0.005")
    })

    it('should set compositeReputation correctly', async () => {
        await wallet.setCompositeReputation("Delivery", 5, { from: PAYMENT_PROCESSOR_CONTRACT })
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

    it('should not allow to change merchant account when paused', async () => {
        await wallet.pause({ from: OWNER })
        const rejected = await wallet.changeMerchantAccount(MERCHANT, { from: MERCHANT2 }).should.be.rejected
        await wallet.unpause({ from: OWNER })

        return rejected
    })

    it('should withdraw money correctly', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        const balance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        await wallet.withdrawTo(MERCHANT, amount, { from: MERCHANT2 })
        const balance2 = new BigNumber(web3.eth.getBalance(MERCHANT))

        balance2.should.bignumber.equal(balance1.plus(amount))
    })

    it('should not allow to withdraw by other accounts', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.withdrawTo(MERCHANT, amount, { from: UNKNOWN }).should.be.rejected
    })

    it('should not allow to withdraw when contract is paused', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.pause({ from: OWNER })
        const rejected = await wallet.withdrawTo(MERCHANT, amount, { from: MERCHANT2 }).should.be.rejected
        await wallet.unpause({ from: OWNER })

        return rejected
    })

    it('should allow deposit all funds to exchange address with transaction', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        const min_amount = 100
        await wallet.withdrawAllToExchange(SAFE_ACCOUNT, min_amount, { from: MERCHANT2 })

        const balance = new BigNumber(web3.eth.getBalance(wallet.address))
        balance.should.bignumber.equal(0)
    })

    it('should allow deposit all funds to exchange address with transaction by monetha', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        const min_amount = 100
        await wallet.withdrawAllToExchange(SAFE_ACCOUNT, min_amount, { from: PAYMENT_PROCESSOR_CONTRACT })

        const balance = new BigNumber(web3.eth.getBalance(wallet.address))
        balance.should.bignumber.equal(0)
    })

    it('should not allow to deposit all funds with transaction when balance is lower than threshold', async () => {
        const balance = new BigNumber(web3.eth.getBalance(wallet.address))

        return await wallet.withdrawAllToExchange(SAFE_ACCOUNT, balance.plus(1), { from: PAYMENT_PROCESSOR_CONTRACT }).should.be.rejected
    })

    it('should not allow other addresses to deposit all funds with transaction', async () => {
        const amount = 0
        await wallet.sendTransaction({ from: OWNER, value: amount })

        return wallet.withdrawAllToExchange(SAFE_ACCOUNT, amount, { from: MERCHANT }).should.be.rejected
    })

    it('should allow deposit to other addresses with transaction', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.withdrawToExchange(SAFE_ACCOUNT, amount, { from: MERCHANT2 })
    })

    it('should allow deposit to other addresses with transaction by monetha', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.withdrawToExchange(SAFE_ACCOUNT, amount, { from: PAYMENT_PROCESSOR_CONTRACT })
    })

    it('should not allow other addresses to deposit with transaction', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        return wallet.withdrawToExchange(SAFE_ACCOUNT, amount, { from: MERCHANT }).should.be.rejected
    })

    it('should not allow deposit with transaction when paused', async () => {
        const amount = 100
        await wallet.sendTransaction({ from: OWNER, value: amount })

        await wallet.pause({ from: OWNER })
        const notRejected = await wallet.withdrawToExchange(SAFE_ACCOUNT, amount, { from: MERCHANT2 }).should.be.rejected
        await wallet.unpause({ from: OWNER })

        return notRejected
    })

    it('should change merchant fund address correctly', async () => {
        await wallet.changeFundAddress(FUND_ADDRESS2, { from: MERCHANT2 })
        const res = await wallet.merchantFundAddress()

        res.should.equal(FUND_ADDRESS2)
    })

    it('should not change merchant fund address by other account', async () => {
        const rejected = await wallet.changeFundAddress(FUND_ADDRESS2, { from: MERCHANT }).should.be.rejected

        return rejected
    })

    it('should not change merchant fund address if fund address is a contract', async () => {
        const rejected = await wallet.changeFundAddress(PAYMENT_PROCESSOR_CONTRACT, { from: MERCHANT }).should.be.rejected

        return rejected
    })
});
