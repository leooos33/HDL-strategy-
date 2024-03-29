# Description

Automated on-chain vault that provides liquidity on Uniswap V3 and hedges its impermanent losses with Squeeth.

# Project structure

```
.
├──  contracts/ # contracts
|──────── core/ # the main contratcs
|──────── interfaces/ # project interfaces
|──────── libraries/ # external libraries
|──────── peripherals/ # peripheral contracts
|──────── rebalancers/ # contracts for executing rebalancing auctions
|──────── IWETH.sol # contract for hardhat testing
|──────── v3Helper.sol # uniswap emulator for hardhat testing
├──  test/ # test cases
├──  .env.example
├──  .gitattributes
├──  .gitignore
├──  .npmignore
├──  README.md # current file
├──  hardhat.config.js
├──  hardhat.helpers.js
├──  package.json
├──  package-lock.json
├──  .prettierignore
├──  .prettierrc
├──  .solhint.json
├──  .solhintignore
├──  .eslintignore
├──  .eslintrc.js
```

# Prerequisites

- Installed NodeJS (tested with NodeJS v16+)

- Installed node modules:

```
npm i
```

- Configure `hardhat.config.js` if [needed](https://hardhat.org/config/).

- Add your <YOUR ALCHEMY KEY> to the .env file. Use .env.example as reference.

# Testing

If you'd like to run tests on the local environment, you might want to run the following command:

```
npm test
```

If you'd like to run pre production tests run the following command:

```
npm run test-prod
```

Hardhat framework is used for testing.

NOTE: if you want to use a different network, configure `hardhat.config.js`.
