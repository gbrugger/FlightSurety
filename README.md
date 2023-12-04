# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`

`truffle compile`

Start Ganache using this mnemonic:

`npx ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -a 100`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`

`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`

`npm run dapp`

To view dapp:

`http://localhost:8000`

Add Ganache running on localhost:8545 as a Network to Metamask to be able to use the wallets and simulate correct authentication.

Add accounts (1) and (2) as airlines. Account 1 is registered when contract is deployed and is automatically funded by dapp.

Add account(6) as passenger.

Switch to account[0] in Metamask and load the page for the first time. The app contract will be authorized.

Switch to account[1] in Metamask and fund the contract with 10 ETH, to be able to participate. Register an airline with the address of account[2].

Switch to account[1] in Metamask and buy insurance for up to 1 ETH.

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder

## Resources

- [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
- [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
- [Truffle Framework](http://truffleframework.com/)
- [Ganache Local Blockchain](http://truffleframework.com/ganache/)
- [Remix Solidity IDE](https://remix.ethereum.org/)
- [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
- [Ethereum Blockchain Explorer](https://etherscan.io/)
- [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)
