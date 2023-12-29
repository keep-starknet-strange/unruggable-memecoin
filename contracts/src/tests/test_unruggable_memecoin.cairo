use openzeppelin::token::erc20::interface::{IERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, RevertedTransaction, CheatTarget
};
use starknet::{ContractAddress, contract_address_const};
use unruggable::amm::amm::{AMM, AMMV2, AMMTrait};

use unruggable::tokens::interface::{
    IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
};


//
// Constants
//
fn RECIPIENT() -> ContractAddress {
    return contract_address_const::<'RECIPIENT'>();
}

fn SPENDER() -> ContractAddress {
    return contract_address_const::<'RECIPIENT'>();
}

const ETH_UNIT_DECIMALS: u256 = 1000000000000000000;

//
// Setup
//

fn deploy_contract(
    owner: ContractAddress,
    name: felt252,
    symbol: felt252,
    initial_supply: u256,
    initial_holders: Span<ContractAddress>,
    initial_holders_amounts: Span<u256>,
) -> Result<ContractAddress, RevertedTransaction> {
    let contract = declare('UnruggableMemecoin');
    let mut constructor_calldata = array![
        owner.into(),
        'locker',
        1000.into(),
        name,
        symbol,
        initial_supply.low.into(),
        initial_supply.high.into()
    ];

    Serde::serialize(@initial_holders.into(), ref constructor_calldata);
    Serde::serialize(@initial_holders_amounts.into(), ref constructor_calldata);
    contract.deploy(@constructor_calldata)
}

fn instantiate_params() -> (
    ContractAddress,
    felt252,
    felt252,
    u256,
    ContractAddress,
    ContractAddress,
    Span<ContractAddress>,
    Span<u256>,
) {
    let owner = contract_address_const::<42>();
    let name = 'UnruggableMemecoin';
    let symbol = 'UM';
    let initial_supply = 1000;
    let initial_holder_1 = contract_address_const::<44>();
    let initial_holder_2 = contract_address_const::<45>();
    let initial_holders = array![initial_holder_1, initial_holder_2].span();
    let initial_holders_amounts = array![50, 50].span();
    (
        owner,
        name,
        symbol,
        initial_supply,
        initial_holder_1,
        initial_holder_2,
        initial_holders,
        initial_holders_amounts
    )
}

mod erc20_metadata {
    use core::debug::PrintTrait;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use super::{deploy_contract, instantiate_params};
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };

    #[test]
    fn test_name() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check name. Should be equal to 'UnruggableMemecoin'.
        let name = memecoin.name();
        assert(name == 'UnruggableMemecoin', 'Invalid name');
    }

    #[test]
    fn test_decimals() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check decimals. Should be equal to 18.
        let decimals = memecoin.decimals();
        assert(decimals == 18, 'Invalid decimals');
    }

    #[test]
    fn test_symbol() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };
        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check symbol. Should be equal to 'UM'.
        let symbol = memecoin.symbol();
        assert(symbol == symbol, 'Invalid symbol');
    }
}

mod erc20_entrypoints {
    use core::array::SpanTrait;
    use core::debug::PrintTrait;
    use core::traits::Into;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{
        declare, ContractClassTrait, start_prank, stop_prank, start_warp, CheatTarget
    };
    use starknet::{ContractAddress, contract_address_const};
    use super::{deploy_contract, instantiate_params};
    use unruggable::tests_utils::deployer_helper::DeployerHelper::{
        deploy_contracts, deploy_unruggable_memecoin_contract, deploy_memecoin_factory, create_eth
    };
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };

    // Test ERC20 snake entrypoints

    #[test]
    fn test_total_supply() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check total supply. Should be equal to initial supply.
        let total_supply = memecoin.total_supply();
        assert(total_supply == initial_supply, 'Invalid total supply');
    }

    #[test]
    fn test_balance_of() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check initial contract balance. Should be equal to 900.
        let balance = memecoin.balanceOf(contract_address);
        assert(balance == 900, 'Invalid balance');
        // Check initial holder 1 balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');
        // Check initial holder 2 balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');
    }

    #[test]
    fn test_approve_allowance() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let spender = super::SPENDER();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check initial allowance. Should be equal to 0.
        let allowance = memecoin.allowance(owner, spender);
        assert(allowance == 0, 'Invalid allowance before');

        // Approve initial supply tokens.
        start_prank(CheatTarget::One(memecoin.contract_address), owner);
        memecoin.approve(spender, initial_supply);

        // Check allowance. Should be equal to initial supply.
        let allowance = memecoin.allowance(owner, spender);
        assert(allowance == initial_supply, 'Invalid allowance after');
    }

    #[test]
    fn test_transfer() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let recipient = super::RECIPIENT();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Transfer 20 tokens to recipient.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        memecoin.transfer(recipient, 20);

        // Check balance. Should be equal to initial balance - 20.
        let initial_holder_1_balance = memecoin.balanceOf(initial_holder_1);
        assert(initial_holder_1_balance == 50 - 20, 'Invalid balance holder 1');

        // Check recipient balance. Should be equal to 20.
        let recipient_balance = memecoin.balanceOf(recipient);
        assert(recipient_balance == 20, 'Invalid balance recipient');
    }

    #[test]
    fn test_transfer_from() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let spender = super::SPENDER();
        let recipient = super::RECIPIENT();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check initial balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');

        // Approve initial supply tokens.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        memecoin.approve(spender, initial_supply);

        // Transfer 20 tokens to recipient.
        start_prank(CheatTarget::One(memecoin.contract_address), spender);
        memecoin.transfer_from(initial_holder_1, recipient, 20);

        // Check balance. Should be equal to initial balance - 20.
        let initial_holder_1_balance = memecoin.balanceOf(initial_holder_1);
        assert(initial_holder_1_balance == 50 - 20, 'Invalid balance holder 1');

        // Check recipient balance. Should be equal to 20.
        let recipient_balance = memecoin.balanceOf(recipient);
        assert(recipient_balance == 20, 'Invalid balance recipient');

        // Check allowance. Should be equal to initial supply - transfered amount.
        let allowance = memecoin.allowance(initial_holder_1, spender);
        assert(allowance == (initial_supply - 20), 'Invalid allowance');
    }

    // Test ERC20 Camel entrypoints

    #[test]
    fn test_totalSupply() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check total supply. Should be equal to initial supply.
        let total_supply = memecoin.totalSupply();
        assert(total_supply == initial_supply, 'Invalid total supply');
    }

    #[test]
    fn test_balanceOf() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check initial contract balance. Should be equal to 900.
        let balance = memecoin.balanceOf(contract_address);
        assert(balance == 900, 'Invalid balance');
        // Check initial holder 1 balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');
        // Check initial holder 2 balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');
    }

    #[test]
    fn test_transferFrom() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let spender = super::SPENDER();
        let recipient = super::RECIPIENT();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Check initial balance. Should be equal to 50.
        let balance = memecoin.balanceOf(initial_holder_1);
        assert(balance == 50, 'Invalid balance');

        // Approve initial supply tokens.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        memecoin.approve(spender, initial_supply);

        // Transfer 20 tokens to recipient.
        start_prank(CheatTarget::One(memecoin.contract_address), spender);
        memecoin.transferFrom(initial_holder_1, recipient, 20);

        // Check balance. Should be equal to initial balance - 20.
        let initial_holder_1_balance = memecoin.balanceOf(initial_holder_1);
        assert(initial_holder_1_balance == 50 - 20, 'Invalid balance holder 1');

        // Check recipient balance. Should be equal to 20.
        let recipient_balance = memecoin.balanceOf(recipient);
        assert(recipient_balance == 20, 'Invalid balance recipient');

        // Check allowance. Should be equal to initial supply - transfered amount.
        let allowance = memecoin.allowance(initial_holder_1, spender);
        assert(allowance == (initial_supply - 20), 'Invalid allowance');
    }
}

mod memecoin_entrypoints {
    use debug::PrintTrait;

    use openzeppelin::token::erc20::interface::{
        IERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait
    };
    use snforge_std::{
        declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp
    };
    use starknet::{ContractAddress, contract_address_const};
    use super::{deploy_contract, instantiate_params, ETH_UNIT_DECIMALS};
    use unruggable::amm::amm::{AMM, AMMV2, AMMTrait};
    use unruggable::amm::jediswap_interface::{
        IFactoryC1, IFactoryC1Dispatcher, IFactoryC1DispatcherTrait, IRouterC1, IRouterC1Dispatcher,
        IRouterC1DispatcherTrait, IPairDispatcher, IPairDispatcherTrait
    };
    use unruggable::tests::utils::{
        deploy_amm_factory_and_router, deploy_meme_factory_with_owner, deploy_locker,
        deploy_eth_with_owner, OWNER, NAME, SYMBOL, ETH_INITIAL_SUPPLY, INITIAL_HOLDERS,
        INITIAL_HOLDERS_AMOUNTS, SALT
    };
    use unruggable::tests_utils::deployer_helper::DeployerHelper::{
        deploy_contracts, deploy_unruggable_memecoin_contract, deploy_memecoin_factory, create_eth
    };

    use unruggable::tokens::factory::{
        IUnruggableMemecoinFactory, IUnruggableMemecoinFactoryDispatcher,
        IUnruggableMemecoinFactoryDispatcherTrait
    };
    use unruggable::tokens::interface::{
        IUnruggableMemecoin, IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };
    use unruggable::tokens::memecoin::UnruggableMemecoin;

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_launch_memecoin_not_owner() {
        // Setup
        let (_, router_address) = deploy_contracts();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

        let (owner, name, symbol, _, _, initial_holder_2, _, _) = instantiate_params();
        let contract_address_salt = 'salty';
        let initial_holders = array![owner].span();
        let initial_holders_amounts = array![1 * ETH_UNIT_DECIMALS].span();

        // Declare availables AMMs for this factory
        let mut amms = array![AMM { name: AMMV2::JediSwap.to_string(), router_address }];

        // Declare UnruggableMemecoin and use ClassHash for the Factory
        let declare_memecoin = declare('UnruggableMemecoin');
        let memecoin_factory_address = deploy_memecoin_factory(
            owner, declare_memecoin.class_hash, amms
        );
        let unruggable_meme_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker_calldata = array![200];
        let locker_contract = declare('TokenLocker');
        let locker_address = locker_contract.deploy(@locker_calldata).unwrap();

        let initial_supply: u256 = 100 * ETH_UNIT_DECIMALS;

        let eth = create_eth(initial_supply, owner, unruggable_meme_factory.contract_address);

        start_prank(CheatTarget::One(unruggable_meme_factory.contract_address), owner);
        // Create a MemeCoin
        let memecoin_address = unruggable_meme_factory
            .create_memecoin(
                owner,
                locker_address,
                name,
                symbol,
                initial_supply,
                initial_holders,
                initial_holders_amounts,
                eth,
                contract_address_salt
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));
        let unruggable_memecoin = IUnruggableMemecoinDispatcher {
            contract_address: memecoin_address
        };
        unruggable_memecoin
            .launch_memecoin(
                AMMV2::JediSwap,
                eth.contract_address,
                1 * ETH_UNIT_DECIMALS,
                1 * ETH_UNIT_DECIMALS,
                100
            );
    }
    #[test]
    fn test_launch_memecoin_happy_path() {
        // Setup
        let (_, router_address) = deploy_amm_factory_and_router();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

        // NOTE:
        // 1. The initial call to `memecoin_address` should be made by the owner.
        // 2. Subsequently, the router needs to call memecoin to transfer tokens to the pool.
        // 3. The second call to `memecoin_address` should be made by the router.
        //    However, note that the prank still designates owner as the caller.
        // Since we can't switch the mock caller target inside a function call, we cannot rely on
        // starknet foundry's `start_prank` to test this.
        // However, if we make the test contract the owner of the memecoin,
        // then we can simply call `launch_memecoin` and all caller contexts will be correct.
        let owner = starknet::get_contract_address();

        let memecoin_factory_address = deploy_meme_factory_with_owner(owner, router_address);
        let memecoin_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker = deploy_locker();

        let (eth, eth_address) = deploy_eth_with_owner(owner);
        start_prank(CheatTarget::One(eth.contract_address), owner);
        eth.approve(spender: memecoin_factory_address, amount: 1 * ETH_UNIT_DECIMALS);
        stop_prank(CheatTarget::One(eth.contract_address));

        start_prank(CheatTarget::One(memecoin_factory_address), owner);
        // Create a MemeCoin
        let memecoin_address = memecoin_factory
            .create_memecoin(
                owner: owner,
                locker_address: locker,
                name: NAME(),
                symbol: SYMBOL(),
                initial_supply: ETH_INITIAL_SUPPLY(),
                initial_holders: INITIAL_HOLDERS(),
                initial_holders_amounts: INITIAL_HOLDERS_AMOUNTS(),
                eth_contract: eth,
                contract_address_salt: SALT(),
            );
        stop_prank(CheatTarget::One(memecoin_factory_address));
        let memecoin = IUnruggableMemecoinDispatcher { contract_address: memecoin_address };

        let memecoin_bal_meme = memecoin.balanceOf(memecoin_address);
        let memecoin_bal_eth = eth.balanceOf(memecoin_address);

        start_prank(CheatTarget::One(router_address), memecoin_address);
        let pool_address = memecoin
            .launch_memecoin(
                AMMV2::JediSwap, eth.contract_address, memecoin_bal_meme, memecoin_bal_eth, 100
            );
        stop_prank(CheatTarget::One(memecoin_factory_address));
        let pool_dispatcher = IPairDispatcher { contract_address: pool_address };
        let (token_0_reserves, token_1_reserves, _) = pool_dispatcher.get_reserves();
        assert(pool_dispatcher.token0() == memecoin_address, 'wrong token 1 address');
        assert(pool_dispatcher.token1() == eth.contract_address, 'wrong token 0 address');
        assert(token_0_reserves == memecoin_bal_meme, 'wrong pool token reserves');
        assert(token_1_reserves == memecoin_bal_eth, 'wrong pool memecoin reserves');
    }
    #[test]
    #[should_panic(expected: ('insufficient memecoin funds',))]
    fn test_launch_memecoin_no_balance_memecoin() {
        // Setup
        let (_, router_address) = deploy_contracts();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            _,
            initial_holders_amounts
        ) =
            instantiate_params();

        let contract_address_salt = 'salty';

        let initial_holders = array![owner].span();
        let initial_holders_amounts = array![1 * ETH_UNIT_DECIMALS].span();

        let initial_supply: u256 = 100 * ETH_UNIT_DECIMALS;

        // Declare availables AMMs for this factory
        let mut amms = array![AMM { name: AMMV2::JediSwap.to_string(), router_address }];

        // Declare UnruggableMemecoin and use ClassHash for the Factory
        let declare_memecoin = declare('UnruggableMemecoin');
        let memecoin_factory_address = deploy_memecoin_factory(
            owner, declare_memecoin.class_hash, amms
        );

        // Deploy UnruggableMemecoinFactory
        let unruggable_meme_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker_calldata = array![200];
        let locker_contract = declare('TokenLocker');
        let locker_address = locker_contract.deploy(@locker_calldata).unwrap();

        let eth = create_eth(initial_supply, owner, unruggable_meme_factory.contract_address);

        // Create a MemeCoin
        start_prank(CheatTarget::One(unruggable_meme_factory.contract_address), owner);
        let memecoin_address = unruggable_meme_factory
            .create_memecoin(
                owner,
                locker_address,
                name,
                symbol,
                initial_supply,
                initial_holders,
                initial_holders_amounts,
                eth,
                contract_address_salt
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));

        let unruggable_memecoin = IUnruggableMemecoinDispatcher {
            contract_address: memecoin_address
        };

        start_prank(CheatTarget::One(memecoin_address), owner);
        unruggable_memecoin
            .launch_memecoin(
                AMMV2::JediSwap,
                eth.contract_address, // this is +1 of initial supply - split to owner 
                100 * ETH_UNIT_DECIMALS,
                1 * ETH_UNIT_DECIMALS,
                100
            );
        stop_prank(CheatTarget::One(memecoin_address));
    }
    #[test]
    #[should_panic(expected: ('ETH balance is not enough',))]
    #[ignore]
    //TODO(tests) refactor the test flow to fix this test
    fn test_launch_memecoin_no_balance_counterparty_token() {
        // Setup
        let (_, router_address) = deploy_amm_factory_and_router();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };
        let initial_holders = array![OWNER()].span();
        let initial_holders_amounts = array![2 * ETH_UNIT_DECIMALS].span();

        // Declare availables AMMs for this factory
        let mut amms = array![];
        amms.append(AMM { name: AMMV2::JediSwap.to_string(), router_address });

        // Declare UnruggableMemecoin and use ClassHash for the Factory
        let declare_memecoin = declare('UnruggableMemecoin');
        let memecoin_factory_address = deploy_memecoin_factory(
            OWNER(), declare_memecoin.class_hash, amms
        );

        // Deploy UnruggableMemecoinFactory
        let unruggable_meme_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker_address = deploy_locker();

        let (eth, eth_address) = deploy_eth_with_owner(OWNER());

        start_prank(CheatTarget::One(unruggable_meme_factory.contract_address), OWNER());
        // Create a MemeCoin
        let memecoin_address = unruggable_meme_factory
            .create_memecoin(
                owner: OWNER(),
                :locker_address,
                name: NAME(),
                symbol: SYMBOL(),
                initial_supply: ETH_INITIAL_SUPPLY(),
                :initial_holders,
                :initial_holders_amounts,
                eth_contract: eth,
                contract_address_salt: SALT()
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));

        let unruggable_memecoin = IUnruggableMemecoinDispatcher {
            contract_address: memecoin_address
        };

        start_prank(CheatTarget::One(memecoin_address), OWNER());
        unruggable_memecoin
            .launch_memecoin(
                AMMV2::JediSwap,
                eth.contract_address,
                1 * ETH_UNIT_DECIMALS,
                1 * ETH_UNIT_DECIMALS,
                100
            );
        stop_prank(CheatTarget::One(memecoin_address));
    }

    #[test]
    #[should_panic(expected: ('ETH allowance not enough',))]
    fn test_launch_memecoin_wrong_allowance_counterparty() {
        // Setup
        let (_, router_address) = deploy_contracts();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };
        let (owner, name, symbol, _, _, _, _, _) = instantiate_params();
        let contract_address_salt = 'salty';
        let initial_holders = array![owner].span();
        let initial_holders_amounts = array![1 * ETH_UNIT_DECIMALS].span();

        let initial_supply: u256 = 100 * ETH_UNIT_DECIMALS;

        // Declare availables AMMs for this factory
        let mut amms = array![];
        amms.append(AMM { name: AMMV2::JediSwap.to_string(), router_address });

        // Declare UnruggableMemecoin and use ClassHash for the Factory
        let declare_memecoin = declare('UnruggableMemecoin');
        let memecoin_factory_address = deploy_memecoin_factory(
            owner, declare_memecoin.class_hash, amms
        );

        // Deploy UnruggableMemecoinFactory
        let unruggable_meme_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker_calldata = array![200];
        let locker_contract = declare('TokenLocker');
        let locker_address = locker_contract.deploy(@locker_calldata).unwrap();

        let erc20_token = declare('ERC20Token');
        let eth_amount: u256 = initial_supply;
        let erc20_calldata: Array<felt252> = array![
            eth_amount.low.into(), eth_amount.high.into(), owner.into()
        ];
        let eth_address = erc20_token
            .deploy_at(
                @erc20_calldata,
                contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >()
            )
            .unwrap();
        let eth = ERC20ABIDispatcher { contract_address: eth_address };
        assert(eth.balanceOf(owner) == initial_supply, 'wrong eth balance');
        start_prank(CheatTarget::One(eth.contract_address), owner);
        eth
            .approve(
                spender: unruggable_meme_factory.contract_address,
                amount: (1 * ETH_UNIT_DECIMALS - 10)
            );
        stop_prank(CheatTarget::One(eth.contract_address));

        start_prank(CheatTarget::One(unruggable_meme_factory.contract_address), owner);
        // Create a MemeCoin
        let memecoin_address = unruggable_meme_factory
            .create_memecoin(
                owner,
                locker_address,
                name,
                symbol,
                initial_supply,
                initial_holders,
                initial_holders_amounts,
                eth,
                contract_address_salt
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));

        let unruggable_memecoin = IUnruggableMemecoinDispatcher {
            contract_address: memecoin_address
        };

        start_prank(CheatTarget::One(memecoin_address), owner);
        unruggable_memecoin
            .launch_memecoin(
                AMMV2::JediSwap,
                eth.contract_address,
                1 * ETH_UNIT_DECIMALS,
                1 * ETH_UNIT_DECIMALS,
                100
            );
        stop_prank(CheatTarget::One(memecoin_address));
    }


    #[test]
    #[should_panic(expected: ('expired',))]
    fn test_launch_memecoin_deadline_expired() {
        // Setup
        let (_, router_address) = deploy_contracts();
        let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };
        let (_, name, symbol, _, _, _, _, _) = instantiate_params();
        let owner = starknet::get_contract_address();
        let contract_address_salt = 'salty';
        let initial_holders = array![owner].span();
        let initial_holders_amounts = array![1 * ETH_UNIT_DECIMALS].span();

        let initial_supply: u256 = 10 * ETH_UNIT_DECIMALS;

        // Declare availables AMMs for this factory
        let mut amms = array![AMM { name: AMMV2::JediSwap.to_string(), router_address }];

        // Declare UnruggableMemecoin and use ClassHash for the Factory
        let declare_memecoin = declare('UnruggableMemecoin');
        let memecoin_factory_address = deploy_memecoin_factory(
            owner, declare_memecoin.class_hash, amms
        );

        // Deploy UnruggableMemecoinFactory
        let unruggable_meme_factory = IUnruggableMemecoinFactoryDispatcher {
            contract_address: memecoin_factory_address
        };

        let locker_calldata = array![200];
        let locker_contract = declare('TokenLocker');
        let locker_address = locker_contract.deploy(@locker_calldata).unwrap();

        let eth = create_eth(initial_supply, owner, unruggable_meme_factory.contract_address);

        start_prank(CheatTarget::One(unruggable_meme_factory.contract_address), owner);
        // Create a MemeCoin
        let memecoin_address = unruggable_meme_factory
            .create_memecoin(
                owner,
                locker_address,
                name,
                symbol,
                initial_supply,
                initial_holders,
                initial_holders_amounts,
                eth,
                contract_address_salt
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));
        let unruggable_memecoin = IUnruggableMemecoinDispatcher {
            contract_address: memecoin_address
        };

        let memecoin_bal_meme = unruggable_memecoin.balanceOf(memecoin_address);
        let memecoin_bal_eth = eth.balanceOf(memecoin_address);
        // Change the block timestamp for Router and Memecoin
        start_warp(CheatTarget::One(memecoin_address), 1000);
        start_warp(CheatTarget::One(router_address), 1000);

        start_prank(CheatTarget::One(router_address), memecoin_address);
        let pool_address = unruggable_memecoin
            .launch_memecoin(
                AMMV2::JediSwap, eth.contract_address, memecoin_bal_meme, memecoin_bal_eth, 100
            );
        stop_prank(CheatTarget::One(unruggable_meme_factory.contract_address));
    }

    #[test]
    fn test_get_team_allocation() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        let team_alloc = memecoin.get_team_allocation();
        // theorical team allocation is 10%, so initial_supply * MAX_TEAM_ALLOC / 100
        // 1000 * 100 / 100 = 100
        assert(team_alloc == 100, 'Invalid team allocation');
    }

    #[test]
    #[should_panic(expected: ('Max buy cap reached',))]
    fn test_transfer_max_percentage() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let alice = contract_address_const::<53>();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Transfer 21 token from owner to alice.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        let send_amount = memecoin.transfer(alice, 21);
    }

    #[test]
    #[should_panic(expected: ('Max buy cap reached',))]
    fn test_transfer_from_max_percentage() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let alice = contract_address_const::<53>();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Transfer 21 token from owner to alice.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        let send_amount = memecoin.transfer_from(initial_holder_1, alice, 500);
    }

    #[test]
    fn test_classic_max_percentage() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();
        let alice = contract_address_const::<53>();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // Transfer 1 token from owner to alice.
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);
        let send_amount = memecoin.transfer(alice, 20);
        assert(memecoin.balanceOf(alice) == 20, 'Invalid balance');
    }
}

mod custom_constructor {
    use core::debug::PrintTrait;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use super::{deploy_contract, instantiate_params};
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };

    #[test]
    #[should_panic(expected: ('Unruggable: arrays len dif',))]
    fn test_constructor_initial_holders_arrays_len_mismatch() {
        let (owner, name, symbol, initial_supply, initial_holder_1, initial_holder_2, _, _) =
            instantiate_params();
        let initial_holder_3 = contract_address_const::<52>();
        let initial_holder_4 = contract_address_const::<53>();
        let initial_holders = array![
            initial_holder_1, initial_holder_2, initial_holder_3, initial_holder_4
        ]
            .span();
        let initial_holders_amounts = array![50, 40, 10].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => address.print(),
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_constructor_initial_holders_arrays_len_is_equal() {
        let (owner, name, symbol, initial_supply, initial_holder_1, initial_holder_2, _, _) =
            instantiate_params();
        let initial_holder_3 = contract_address_const::<52>();
        // array_len is 4
        let initial_holders = array![initial_holder_1, initial_holder_2, initial_holder_3].span();
        // array_len is 4
        let initial_holders_amounts = array![50, 40, 10].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    #[should_panic(expected: ('Unruggable: max holders reached',))]
    fn test_max_holders_reached() {
        let (owner, name, symbol, initial_supply, initial_holder_1, initial_holder_2, _, _) =
            instantiate_params();
        let initial_holder_3 = contract_address_const::<52>();
        let initial_holder_4 = contract_address_const::<53>();
        let initial_holder_5 = contract_address_const::<54>();
        let initial_holder_6 = contract_address_const::<55>();
        let initial_holder_7 = contract_address_const::<56>();
        let initial_holder_8 = contract_address_const::<57>();
        let initial_holder_9 = contract_address_const::<58>();
        let initial_holder_10 = contract_address_const::<59>();
        let initial_holder_11 = contract_address_const::<60>();
        // 11 holders
        let initial_holders = array![
            initial_holder_1,
            initial_holder_2,
            initial_holder_3,
            initial_holder_4,
            initial_holder_5,
            initial_holder_6,
            initial_holder_7,
            initial_holder_8,
            initial_holder_9,
            initial_holder_10,
            initial_holder_11,
        ]
            .span();
        let initial_holders_amounts = array![1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,].span();

        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => address.print(),
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_max_holders_not_reached() {
        let (owner, name, symbol, initial_supply, initial_holder_1, initial_holder_2, _, _) =
            instantiate_params();
        let initial_holder_3 = contract_address_const::<52>();
        let initial_holder_4 = contract_address_const::<53>();
        let initial_holder_5 = contract_address_const::<54>();
        // 6 holders
        let initial_holders = array![
            initial_holder_1,
            initial_holder_2,
            initial_holder_3,
            initial_holder_4,
            initial_holder_5,
        ]
            .span();
        let initial_holders_amounts = array![50, 47, 1, 1, 1,].span();

        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_initial_recipient_ok() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts
        ) =
            instantiate_params();

        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    #[should_panic(expected: ('Unruggable: max team allocation',))]
    fn test_max_team_allocation_fail() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        // team should have less than 100 tokens
        let initial_holders_amounts = array![100, 50,].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => address.print(),
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_max_team_allocation_ok() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        // team should have less than 100 tokens
        let initial_holders_amounts = array![50, 50,].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_max_team_allocation_ok2() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        // team should have less than 100 tokens
        let initial_holders_amounts = array![50, 40,].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }

    #[test]
    fn test_max_supply_reached_ok() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        // team should have less than 101 tokens
        let initial_holders_amounts = array![50, 50].span();
        match deploy_contract(
            owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
        ) {
            Result::Ok(address) => {},
            Result::Err(msg) => panic(msg.panic_data),
        }
    }
}

mod memecoin_internals {
    use UnruggableMemecoin::{
        UnruggableMemecoinInternalImpl, SnakeEntrypoints, UnruggableEntrypoints,
        MAX_HOLDERS_BEFORE_LAUNCH
    };
    use core::debug::PrintTrait;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use super::{deploy_contract, instantiate_params};
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };
    use unruggable::tokens::memecoin::UnruggableMemecoin;

    #[test]
    fn test__transfer_recipients_equal_holder_cap() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts,
        ) =
            instantiate_params();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set initial_holder_1 as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);

        let mut index = 0;
        loop {
            // MAX_HOLDERS_BEFORE_LAUNCH - 2 because there are 2 initial holders
            if index == MAX_HOLDERS_BEFORE_LAUNCH - 2 {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            // Check recipient balance. Should be equal to 1.
            let recipient_balance = memecoin.balanceOf(unique_recipient);
            assert(recipient_balance == 1, 'Invalid balance recipient');

            index += 1;
        };
    }

    #[test]
    fn test__transfer_initial_holder_whole_balance() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _,
        ) =
            instantiate_params();
        let initial_holders_amounts = array![50, 20].span();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set initial_holder_1 as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);

        let mut index = 0;
        loop {
            // MAX_HOLDERS_BEFORE_LAUNCH - 2 because there are 2 initial holders
            if index == MAX_HOLDERS_BEFORE_LAUNCH - 2 {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            // Check recipient balance. Should be equal to 1.
            let recipient_balance = memecoin.balanceOf(unique_recipient);
            assert(recipient_balance == 1, 'Invalid balance recipient');

            index += 1;
        };

        let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

        // Send initial_holder_2 whole balance to the unique recipient
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_2);
        memecoin.transfer(unique_recipient, 20);

        // Check recipient balance. Should be equal to 0.
        let initial_holder_2_balance = memecoin.balanceOf(initial_holder_2);
        assert(initial_holder_2_balance.is_zero(), 'Invalid balance holder 2');
    }

    #[test]
    fn test__transfer_existing_holders() {
        /// pre launch holder number should not change when
        /// transfer is done to recipient(s) who already have tokens

        /// to test this, we are going to continously self transfer tokens
        /// and ensure that we can transfer more than `MAX_HOLDERS_BEFORE_LAUNCH` times

        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            initial_holders_amounts,
        ) =
            instantiate_params();
        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set initial_holder_1 as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // Self transfer tokens
            memecoin.transfer(initial_holder_2, 1);

            index += 1;
        };
    }

    #[test]
    #[should_panic(expected: ('Unruggable: max holders reached',))]
    fn test__transfer_above_holder_cap() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        let initial_holders_amounts = array![50, 30].span();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set initial_holder_1 as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), initial_holder_1);

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            index += 1;
        };
    }

    // TODO: Uncomment test when foundry solves issue (read comment)
    // #[test]
    fn test__transfer_no_holder_cap_after_launch() {
        let (
            owner,
            name,
            symbol,
            initial_supply,
            initial_holder_1,
            initial_holder_2,
            initial_holders,
            _
        ) =
            instantiate_params();
        let initial_holders_amounts = array![50, 30,].span();

        let contract_address =
            match deploy_contract(
                owner, name, symbol, initial_supply, initial_holders, initial_holders_amounts
            ) {
            Result::Ok(address) => address,
            Result::Err(msg) => panic(msg.panic_data),
        };

        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set owner as caller to launch the token
        start_prank(CheatTarget::All, owner);

        // NOTE:
        // 1. The initial call to `memecoin_address` should be made by the owner.
        // 2. Subsequently, the router needs to call memecoin to transfer tokens to the pool.
        // 3. The second call to `memecoin_address` should be made by the router.
        //    However, note that the prank still designates owner as the caller.
        // `set_contract_address()` from starknet cannot be used in this context.
        // related issue: https://github.com/foundry-rs/starknet-foundry/issues/1402

        // start_prank(CheatTarget::One(memecoin_address), router_address);
        // start_prank(CheatTarget::One(router_address), memecoin_address);
        // unruggable_memecoin
        //     .launch_memecoin(
        //         AMMV2::JediSwap, counterparty_token_address, 20000000000000000, 1 * ETH_UNIT_DECIMALS
        //     );
        // TODO: call launch_memecoin() with params
        // memecoin.launch_memecoin();

        // set initial_holder_1 as caller to distribute tokens
        start_prank(CheatTarget::All, initial_holder_1);

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            index += 1;
        };
    }
}

