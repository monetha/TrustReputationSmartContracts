require("babel-register");
require("babel-polyfill");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 3600000,
      gasPrice: 21
    },
    kovan: {
      host: "localhost",
      port: 8545,
      network_id: "42",
      gasPrice: 1000000000
    },
    ropsten: {
      host: "localhost",
      port: 8545,
      network_id: "3",
      gasPrice: 1000000000
    },
    live: {
      host: "localhost",
      port: 8545,
      network_id: "1"
    },
    ganache: {
      host: "localhost",
      port: 7545,
      network_id: 5777,
      gas: 6721975,
      gasPrice: 21
    }
  },

  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
