#!/usr/bin/env bash

# Based on https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/scripts/test.sh

# Executes cleanup function at script exit.
trap cleanup EXIT

cleanup() {
  # Kill the ganache-cli instance that we started (if we started one and if it's still running).
  if [ -n "$ganache_cli_pid" ] && ps -p $ganache_cli_pid > /dev/null; then
    kill -9 $ganache_cli_pid
  fi
}

ganache_cli_running() {
  nc -z localhost 8545
}

run_ganache_cli() {
  ganache-cli --account="0x129c5743e4cc428a6feb3c3963fe06ad73d485acd8bb4b9cb090f56b961a934e, 100000000000000000000000000000000" --account="0xa76d83a00b24c23b881e2891312f2c1bef302922752fc2953cf39c3dfcd0f738, 100000000000000000000000000000000" --account="0x05a23befc0635f33e7c50f64084a711b92b15321d04b070f82194d7c872a7161, 100000000000000000000000000000000" --account="0xd582dd6615191be88ec76c86bdc0e26cf5d7544cf889415e6d2805e5a8408675, 100000000000000000000000000000000" --account="0x258c16c5bf24b74a56943fb1a57ba7cb04f6c24324d9256f7514c0838437e94a, 100000000000000000000000000000000" --account="0x7e2b9438c59e8f7e11e6c9060ae595a5645ce040ba1a8659926c39a32284c066, 100000000000000000000000000000000" --account="0xd10e4f31a007d8724656cd0af38530f0d0f2bc0895cc01599eb0ff985a7a378b, 100000000000000000000000000000000" --account="0x890b7db32d5a01f65e6858c65251eab55ed64d9f0f3b76568783df3b54b75bb3, 100000000000000000000000000000000" --account="0x8714de973f2e9585bec1f11a01a2ae1cf88cfb73ec12ed1f62c60de8aa9da32d, 100000000000000000000000000000000" --account="0x1de31fb89294be0f75bbb92b2bfa4436f9bc1c6082d28d51cdce69ca1ca80a49, 100000000000000000000000000000000" > /dev/null &
}

if ganache_cli_running; then
  echo "Using existing ganache-cli instance"
else
  echo "Starting our own ganache-cli instance"
  run_ganache_cli
  ganache_cli_pid=$!
fi

node_modules/.bin/truffle test --network development"$@"
