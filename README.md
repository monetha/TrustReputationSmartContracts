# Monetha gateway smart contracts

## Abstract


## Main components
*  **Merchant Wallet**
Serves as a public Merchant profile with merchant profile info, payment settings and latest reputation value. Also it accepts payments for orders.

*  **Merchant's acceptor**
Process ether payments for orders. Possibility to pay with ERC20 tokens will be added in the future.

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
