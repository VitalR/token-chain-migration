# include .env file and export its env vars
# (-include to ignore error if it does not exist)
include .env

.PHONY: update build size inspect selectors test trace gas test-contract test-contract-gas trace-contract test-test trace-test clean snapshot anvil deploy

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# deps
update :; forge update
build :; forge build
size :; forge build --sizes

# storage inspection
inspect :; forge inspect ${contract} storage-layout --pretty
# get the list of function selectors
selectors :; forge inspect ${contract} methods --pretty

# local tests without fork
test-swap :; forge test --match-contract SwapUnitTest -vvv
test :; forge test --match-contract UnitTest -vvv
trace :; forge test -vvvv
gas :; forge test --gas-report
test-contract :; forge test -vvv --match-contract $(contract)
test-contract-gas :; forge test --gas-report --match-contract ${contract}
trace-contract :; forge test -vvvv --match-contract $(contract)
test-test :; forge test -vvv --match-test $(test)
trace-test :; forge test -vvvv --match-test $(test)

clean :; forge clean
snapshot :; forge snapshot

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Deploy Cross Chain Swap & Vesting contracts to testnet:
deploy-bep20 :; source .env && forge script script/00_DeployArtcoinBEP20.s.sol:DeployArtcoinBEP20Script --rpc-url ${BNBTESTNET_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${BNBSCAN_API_KEY} --gas-price ${GAS_PRICE} --gas-limit ${GAS_LIMIT} -vvvv
deploy-token :; source .env && forge script script/01_DeployArtcoinERC20.s.sol:DeployArtcoinScript --rpc-url ${AMOY_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} --gas-price ${GAS_PRICE} --gas-limit ${GAS_LIMIT} -vvvv
deploy-swap :; source .env && forge script script/02_DeployCrossChainSwap.s.sol:DeployCrossChainSwapScript --rpc-url ${BNBTESTNET_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${BNBSCAN_API_KEY} --gas-price ${GAS_PRICE} --gas-limit ${GAS_LIMIT} -vvvv
deploy-vesting :; source .env && forge script script/03_DeployCrossChainVesting.s.sol:DeployCrossChainVestingScript --rpc-url ${AMOY_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} --gas-price ${GAS_PRICE} --gas-limit ${GAS_LIMIT} -vvvv
postdeploy-setup-swap :; source .env && forge script script/04_PostDeploySwapSetUp.s.sol:PostDeploySwapSetUpScript --rpc-url ${BNBTESTNET_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast -vvvv
postdeploy-setup-vesting :; source .env && forge script script/05_PostDeployVestingSetUp.s.sol:PostDeployVestingSetUpScript --rpc-url ${AMOY_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast -vvvv
execute-swap :; source .env && forge script script/ExecuteCrossChainSwap.s.sol:ExecuteCrossChainSwapScript --rpc-url ${BNBTESTNET_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --gas-limit 40000000 --broadcast -vvvv
