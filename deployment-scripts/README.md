# Deployment guideline

For deployment, you need to run local Ethereum node with desired network.

In `../truffle.js` config file you need to specify `from` account in desired network section.
This account will be using for contracts deployment. For example:
```
live: {
  host: "localhost",
  port: 8545,
  network_id: "1",
  from: "0x3d246f591dc69f1747e56e4558601c38146f6662"
}
```

Also you need to specify accounts addresses and constructor parameters for all contracts inside `config.json`.

1. **Infrastructure contract: MonethaGateway**

    From current folder execute next command:
    ```
    truffle exec --network=<network> deploy-infrastructure.js
    ```

    After MonethaGateway deployment you need to update MonethaGateway address in `config.json`.

2. **Merchant contracts deployment: Wallet, MerchantDealsHistory, PaymentProcessor**

    From current folder execute next command:
    ```
    truffle exec --network=<network> deploy-merchant.js
    ```