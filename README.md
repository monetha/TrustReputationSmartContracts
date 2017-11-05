# Monetha gateway smart contracts

## Abstract
*Universal​ ​decentralized​ ​trust​ ​and​ ​reputation​ platform*

We aim to solve following problems:
1. Not all online merchants have their trust profile.
Building trust is difficult. It takes time and costs a lot of money. It’s even more difficult for new or small merchants.
Trust and reputation are extremely important for participants of today’s global commerce.

2. Merchants reputation is not transferable.
Merchants have no​ ​ability​ ​to​ ​transfer​ ​their​ ​trust​ ​rate​ ​from​ one centralized service to another. For example, once you become trusted on Amazon, you still must build your trust *from zero* on other marketplaces or *your* own website.

3. Trust and reputation works two ways.
Since the beginning of online commerce, one of the major problems buyers face is feeling safe before, during and after the purchase. 
Our goal is to apply the trust and reputation via different functionalities in different stages of purchase:
*  Before the purchase: Immutable, public, accurate reputation that is always linked to a payment.
*  During the purchase: Formalising the purchase with a smart contract; Escrow.
*  After the purchase: Ability to claim.

No more fear, uncertainty or doubt buying online. Monetha aims to bring the same trustful feeling that you have shopped in a famous retail store to any merchant’s shop, anywhere in the world.

## Main components
*  **Merchant Wallet**
Serves as a public Merchant profile with merchant profile info, payment settings and latest reputation value. Also it accepts payments for orders.

*  **Merchant's acceptor**
Process ether payments for orders. Possibility to pay with ERC-20 tokens will be added in the future.

*  **Client and Merchant Deals History**
Contract stores hash of deals conditions together with parties reputation for each deal. This history enables to see evolution of trust rating for both parties.

*  **Client's Wallet (TBD)**
Client's profile, payment settings and reputation.

## Prerequisites

* [Node.js](https://nodejs.org/en/download/) v8.5.0+
* [truffle](http://truffleframework.com/) v3.4.11+
* [testrpc](https://github.com/ethereumjs/testrpc) v4.1.3+

## How to run tests

In separate terminal run next command:
```
testrpc
```

In a main terminal from the project folder run next command:
```
truffle test
```

## How to deploy to testnet/mainnet

In separate terminal run your Ethereum node on `8545` port ([Parity](https://parity.io/), for example).

And in main terminal run one of next commans:

For mainnet
```
truffle migrate --network=live
```

For kovan testnet
```
truffle migrate --network=kovan
```

You can add settings for another network in `truffle.js` file
