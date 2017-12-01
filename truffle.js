module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    kovan: {
      host: "localhost",
      port: 8545,
      network_id: "42",
      gasPrice: 1000000000
    },
    live: {
      host: "localhost",
      port: 8545,
      network_id: "1"
    }
  }
};
