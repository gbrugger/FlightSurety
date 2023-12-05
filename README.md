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

Add Ganache running on localhost:8545 as a Network to Metamask to be able to use the wallets and simulate correct authorization for each profile.

Account [1] is registered when contract is deployed.
Add accounts [1] and [2] to Metamask as airlines.

Add account [6] to Metamask as passenger.

Switch to account [0] (contract owner) in Metamask and load the page for the first time. The app contract will be authorized. If you use an account other than the data contract's owner, authorization will not work.

Switch to account [1] in Metamask and fund the contract with 10 ETH, to be able to participate. The event will be printed to the server console. Then, register an airline with the address of account [2].

Switch to account [2] in Metamask and fund airline with account [2] to make the first 2 flights in the flight list to work. In a real dapp, the flight list would be dynamic,as airlines engage with the contract.

Switch to account [6] in Metamask and buy insurance for up to 1 ETH in one of the flights. If the airline that provides the flight is not funded, an error will be thrown in the UI.

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
