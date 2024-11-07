# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# only export these env vars if ENVIRONMENT = local
export BASE_RPC_URL := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)

# deps
install:; forge install
update:; forge update

# Build & test
build :; forge build
ftest   :; forge test
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt && forge fmt test/
coverage :; forge coverage --report lcov
