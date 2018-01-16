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

Also you need to compile your contracts before deployment:
```
truffle compile
```

1. **Infrastructure contract: MonethaGateway**

    You need to specify deployment parameters for contracts inside `config.json`.

    For example:
    ```
    {
        "processingAddress": "0xb78d7a1a082e19f36353721dc133d5c6f09ccea8",
        "ownerAddress": "0x3d246f591dc69f1747e56e4558601c38146f6662",
        "vaultAddress": "0x00861d9C49d274A6863B45850e0F01C4874DF341",
        "monethaGatewayAddress": "0xE808419C664160017D2D5eebc74e14fBDaaaD1F5"
    }
    ```

    From current folder execute next command:
    ```
    truffle exec --network=<network> deploy-infrastructure.js
    ```

    After MonethaGateway deployment you need to update `monethaGatewayAddress` in `config.json`.

2. **Merchant contracts deployment: Wallet, MerchantDealsHistory, PaymentProcessor**

    You need to specify merchant-related settings inside merchant config file.
    For example:
    ```
    {
        "merchantAddress": "0x003f57bB9328f07eb40C3b1B19ed14e879DAB0f4",
        "merchantId": "id"
    }
    ```

    From current folder execute next command:
    ```
    truffle exec --network=<network> deploy-merchant.js <path to merchant config file>
    ```

    For example:
    ```
    truffle exec --network=live deploy-merchant.js ./merchant1-config-example.json
    ```