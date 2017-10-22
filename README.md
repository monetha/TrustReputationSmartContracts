# Trust and Reputation Smart Contracts**

## Specification
*  Monetha gateway: https://docs.google.com/document/d/1auJ9u6_27_4YULcBKpeXGH9RQYiA31xbk3NNzLUIGg0/edit
*  Payment uniqueness: https://docs.google.com/document/d/18DBJw3zCfPO2UYf_kr9a_DwPDHW2a1_39gweH7UFsZA/edit#heading=h.b59hnyspshjq

## Main components
*  Merchant Wallet: merchant profile, payment settings, reputation
*  Merchant's acceptor contracts
*  Global Acceptor contracts
*  CLient's Wallet: profile, payment settings, reputation (future)

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

In separate terminal run next your Ethereum node on `8545` port ([Parity](https://parity.io/), for example).

And in main terminal run one of next commans:

For mainnet
```
truffle migrate --network=live
```

For kovan testnet
```
truffle migrate --network=kovan
```

P.S. you can add settings for another network in `truffle.js` file
