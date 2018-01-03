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
    const PROCESSOR = accounts[3]

    let gateway

    before(async () => {
        gateway = await MonethaGateway.new(VAULT, PROCESSOR)
    });

    it('should accept payment correctly', async () => {
        const value = new BigNumber('1e9')
        const feeCoeff = new BigNumber(await gateway.FEE_PERMILLE()).div(1000)

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.acceptPayment(MERCHANT, { value: value, from: PROCESSOR })

        const merchantBalance2 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance2 = new BigNumber(web3.eth.getBalance(VAULT))

        const deltaMerchant = merchantBalance2.minus(merchantBalance1)
        const deltaVault = vaultBalance2.minus(vaultBalance1)
        
        deltaMerchant.should.bignumber.equal(value.mul(new BigNumber(1).minus(feeCoeff)))
        deltaVault.should.bignumber.equal(value.mul(feeCoeff))
    })

    it('should not accept payment when contract is paused', async () => {
        const value = new BigNumber('1e9')
        const feeCoeff = new BigNumber(await gateway.FEE_PERMILLE()).div(1000)

        const merchantBalance1 = new BigNumber(web3.eth.getBalance(MERCHANT))
        const vaultBalance1 = new BigNumber(web3.eth.getBalance(VAULT))

        await gateway.pause({from:OWNER})

        await gateway.acceptPayment(MERCHANT, { value: value, from: PROCESSOR }).should.be.rejected
    })
});
