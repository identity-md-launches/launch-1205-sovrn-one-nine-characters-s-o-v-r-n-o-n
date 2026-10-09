// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {SystemBase} from "./SystemBase.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {SovrnHook} from "../src/SovrnHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

/// @dev During the opening decay only the launch factory (this test contract) may add liquidity, except inside the
///      pool's initializing transaction. This closes the IMD-only-range route around the opening buy fee.
contract LiquidityLockTest is SystemBase {
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        // _system(true) seeds through a router in the initializing transaction, which must be allowed.
        _system(true);
    }

    /// @dev A range holding only IMD, sitting beside the price on the side sellers push toward.
    function _imdOnlyRange() internal view returns (ModifyLiquidityParams memory) {
        return _imdIsCurrency0()
            ? ModifyLiquidityParams(-184200, -166200, 1e21, bytes32(0))
            : ModifyLiquidityParams(166200, 184200, 1e21, bytes32(0));
    }

    function test_seedingInTheInitializingTransactionByAnyRouterWorked() public view {
        // setUp initialized the pool and seeded 1e22 liquidity through a router that is not the factory.
        assertEq(block.timestamp, hook.openedAt());
        assertGt(StateLibrary.getLiquidity(manager, key.toId()), 0);
    }

    function test_laterTransactionInTheOpeningSecondCannotAdd() public {
        // setUp seeded in the initializing transaction. A later transaction with the same timestamp is not exempt.
        assertEq(block.timestamp, hook.openedAt());
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
    }

    function test_othersCannotAddLiquidityDuringTheDecay() public {
        vm.warp(hook.openedAt() + 1);
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
        vm.warp(hook.openedAt() + hook.DECAY() - 1);
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
    }

    function test_anyoneCanAddOnceTheDecayIsOver() public {
        vm.warp(hook.openedAt() + hook.DECAY());
        router.liquidity(key, _imdOnlyRange());
        vm.prank(ALICE);
        router.liquidity(key, ModifyLiquidityParams(-60, 60, 1e18, bytes32(0)));
    }

    function test_removingLiquidityIsNeverBlocked() public {
        vm.warp(hook.openedAt() + 1);
        router.liquidity(key, ModifyLiquidityParams(-887220, 887220, -1e18, bytes32(0)));
    }

    function test_factoryCanAddDuringTheDecay() public {
        vm.warp(hook.openedAt() + 5 minutes);
        ModifyLiquidityParams memory p = ModifyLiquidityParams(-60, 60, 1e18, bytes32(0));
        ERC20(address(token)).approve(address(this), type(uint256).max);
        manager.unlock(abi.encode(p));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager));
        ModifyLiquidityParams memory p = abi.decode(data, (ModifyLiquidityParams));
        (BalanceDelta d,) = manager.modifyLiquidity(key, p, "");
        _pay(key.currency0, d.amount0());
        _pay(key.currency1, d.amount1());
        return "";
    }

    function _pay(Currency c, int128 amount) private {
        if (amount >= 0) return;
        manager.sync(c);
        ERC20(Currency.unwrap(c)).transfer(address(manager), uint256(uint128(-amount)));
        manager.settle();
    }

    function test_bypassNoLongerPaysLessThanTheBuyFee() public {
        // The old exploit: add an IMD-only range, let a seller push SVO in, end up with SVO and no buy fee.
        vm.warp(hook.openedAt() + 1);
        uint256 before = _vaultIMD();
        vm.expectRevert();
        router.liquidity(key, _imdOnlyRange());
        assertEq(_vaultIMD(), before);
    }
}

contract LiquidityLockReversedTest is LiquidityLockTest {
    function _imdIsCurrency0() internal pure override returns (bool) {
        return false;
    }
}
