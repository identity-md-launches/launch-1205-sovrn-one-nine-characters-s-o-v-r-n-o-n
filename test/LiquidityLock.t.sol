// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {SystemBase} from "./SystemBase.sol";
import {PoolRouter} from "./PoolRouter.sol";
import {SovrnHook} from "../src/SovrnHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

/// @dev Plays the launch factory: initializes the pool and, in the same call, seeds it through another contract
///      (the "outsider" router), as a factory that delegates seeding would.
contract AtomicOpener {
    function open(IPoolManager m, PoolRouter seeder, PoolKey memory key, uint160 price, ModifyLiquidityParams memory p)
        external
    {
        ERC20(Currency.unwrap(key.currency0)).approve(address(seeder), type(uint256).max);
        ERC20(Currency.unwrap(key.currency1)).approve(address(seeder), type(uint256).max);
        m.initialize(key, price);
        seeder.liquidity(key, p);
    }

    function addLater(PoolRouter seeder, PoolKey memory key, ModifyLiquidityParams memory p) external {
        seeder.liquidity(key, p);
    }
}

/// @dev During the opening decay only the launch factory may add liquidity, plus anyone inside the pool's
///      initializing transaction. This closes the IMD-only-range route around the opening buy fee. In the fixture
///      the router is the factory; `outsider` is any other contract.
contract LiquidityLockTest is SystemBase {
    using PoolIdLibrary for PoolKey;

    PoolRouter internal outsider;

    function setUp() public {
        _system(true);
        outsider = new PoolRouter(manager);
        token.approve(address(outsider), type(uint256).max);
        imd.approve(address(outsider), type(uint256).max);
        vm.startPrank(ALICE);
        token.approve(address(outsider), type(uint256).max);
        imd.approve(address(outsider), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev A range holding only IMD, sitting beside the price on the side sellers push toward.
    function _imdOnlyRange() internal view returns (ModifyLiquidityParams memory) {
        return _imdIsCurrency0()
            ? ModifyLiquidityParams(-184200, -166200, 1e21, bytes32(0))
            : ModifyLiquidityParams(166200, 184200, 1e21, bytes32(0));
    }

    function test_theFactorySeededThePool() public view {
        assertEq(hook.factory(), address(router));
        assertGt(StateLibrary.getLiquidity(manager, key.toId()), 0);
    }

    function test_othersCannotAddInTheOpeningSecondEither() public {
        // A later transaction with the very same timestamp gets no exemption.
        assertEq(block.timestamp, hook.openedAt());
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
    }

    function test_othersCannotAddLiquidityDuringTheDecay() public {
        vm.warp(hook.openedAt() + 1);
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
        vm.warp(hook.openedAt() + hook.DECAY() - 1);
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
    }

    function test_theFactoryCanAddDuringTheDecay() public {
        vm.warp(hook.openedAt() + 5 minutes);
        router.liquidity(key, ModifyLiquidityParams(-60, 60, 1e18, bytes32(0)));
    }

    function test_anyoneCanAddOnceTheDecayIsOver() public {
        vm.warp(hook.openedAt() + hook.DECAY());
        outsider.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        outsider.liquidity(key, ModifyLiquidityParams(-60, 60, 1e18, bytes32(0)));
    }

    function test_removingLiquidityIsNeverBlocked() public {
        vm.warp(hook.openedAt() + 1);
        router.liquidity(key, ModifyLiquidityParams(-887220, 887220, -1e18, bytes32(0)));
    }

    function test_bypassDoesNotWork() public {
        // The old exploit: add an IMD-only range, let a seller push SVO in, end up with SVO and no buy fee.
        vm.warp(hook.openedAt() + 1);
        uint256 before = _vaultIMD();
        vm.expectRevert();
        outsider.liquidity(key, _imdOnlyRange());
        assertEq(_vaultIMD(), before);
    }
}

/// @dev The exemption covers the initializing transaction only: a factory that seeds through another contract in
///      the same call works (setUp), and a later transaction through the same contract is locked out (the tests).
contract AtomicOpenTest is SystemBase {
    using PoolIdLibrary for PoolKey;

    PoolRouter internal seeder;
    AtomicOpener internal opener;
    SovrnHook internal h;
    PoolKey internal k;
    ModifyLiquidityParams internal range = ModifyLiquidityParams(-887220, 887220, 1e20, bytes32(0));

    function setUp() public {
        _system(true);
        seeder = new PoolRouter(manager);
        opener = new AtomicOpener();
        address at = address(uint160(0xe8cc));
        deployCodeTo("SovrnHook.sol:SovrnHook", abi.encode(IPoolManager(address(manager)), token, address(opener)), at);
        h = SovrnHook(payable(at));
        k = key;
        k.hooks = IHooks(at);
        token.transfer(address(opener), 1_000_000 ether);
        imd.transfer(address(opener), 10 ether);
        opener.open(manager, seeder, k, _orient(START_PRICE), range);
    }

    function test_seedingThroughAnotherContractInTheInitializingCallWorked() public view {
        assertGt(StateLibrary.getLiquidity(manager, k.toId()), 0);
        assertEq(h.openedAt(), block.timestamp);
    }

    function test_aLaterTransactionThroughTheSameContractIsLockedOut() public {
        vm.expectRevert();
        opener.addLater(seeder, k, range);
    }
}

contract AtomicOpenReversedTest is AtomicOpenTest {
    function _imdIsCurrency0() internal pure override returns (bool) {
        return false;
    }
}

contract LiquidityLockReversedTest is LiquidityLockTest {
    function _imdIsCurrency0() internal pure override returns (bool) {
        return false;
    }
}
