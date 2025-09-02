// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.26;
// Line
// pragma solidity ^0.8.20;
// Bsc
pragma solidity ^0.8.24;

// abstract contract UniswapV2Factory {
//     function allPairs(uint256 index) external view virtual returns(address);
// }
// abstract contract UniswapV2Pair {
//     function token0() external view virtual returns(address);
//     function token1() external view virtual returns(address);
//     function getReserves() external view virtual returns(uint112, uint112, uint32);
// }

// abstract contract UniswapV3PositionManager {
//     function positions(uint256 tokenId) external view virtual returns(uint96 nonce, address operator, address token0, address token1, uint24 fee,
//         int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1);
// }

abstract contract UniswapV3Factory {
    function getPool(address token0, address token1, uint24 fee) external view virtual returns(address pool);
}

abstract contract UniswapV3Pool {
    function token0() external view virtual returns(address token);
    function token1() external view virtual returns(address token);
    function tickSpacing() external view virtual returns(int24 spacing);
    function slot0() external view virtual returns(uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
}

abstract contract UniswapV3PoolEx {
    function slot0() external view virtual returns(uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint32 feeProtocol, bool unlocked);
}

abstract contract MetaRegistry {
    function pool_list(uint256 index) external view virtual returns (address);
    function get_balances(address pool) external view virtual returns (uint256[8] memory balances);
    function get_fees(address pool) external view virtual returns (uint256[10] memory fees);
    function is_registered(address pool) external view virtual returns (bool);
    function get_pool_params(address pool) external view virtual returns (uint256[20] memory params);
    function get_coins(address pool) external view virtual returns (address[8] memory coins);
}

// abstract contract ERC20 {
    // function balanceOf(address addr) external view virtual returns(uint256);
    // function decimals() external view virtual returns(uint8);
    // function name() external view virtual returns(string memory);
    // function symbol() external view virtual returns(string memory);
    // function totalSupply() external view virtual returns(uint256);
// }

contract UniswapTool {
    // V2 Factory
    // UniswapV2Factory factoryV2 = UniswapV2Factory(0x733E88f248b742db6C14C0b1713Af5AD7fDd59D0);
    // address factoryV2 = address(0x733E88f248b742db6C14C0b1713Af5AD7fDd59D0);
    // address factoryPancakeV2 = address(0x82438CE666d9403e488bA720c7424434e8Aa47CD); // Router 0x3a3eBAe0Eec80852FBC7B9E824C6756969cc8dc1
    // V3 NonfungiblePositionManager
    // UniswapV3PositionManager positionManagerV3 = UniswapV3PositionManager(0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7);
    // address positionManagerV3 = address(0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7);
    // V3 Factory
    // UniswapV3Factory factoryV3 = UniswapV3Factory(0x961235a9020B05C44DF1026D956D1F4D78014276);

    struct Position {
        address addr;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        int24 tickSpacing;
    }

    struct Pair {
        address addr;
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint32 lastTime;
    }

    struct CurvePool {
        address addr;
        address[8] tokens;
        uint256[8] reserves;
        uint64 amp;
        uint256[10] fees;
        bool registered;
    }

    struct CurvePoolUpdate {
        uint256[8] reserves;
        uint64 amp;
        bool registered;
    }

    struct Token {
        uint256 supply;
        uint8 decimals;
        string name;
        string symbol;
        bool error;
    }

    function queryV2NewPairs(address factoryV2, uint32 fromIndex, uint16 count) external view returns(Pair[] memory validPairs) {
        // 先确定实际能查询的数量
        uint16 validCount = 0;
        Pair[] memory allPairs = new Pair[](count);
        bool success;
        bytes memory pairBytes;
        for (uint16 i = 0; i < count; i++) {
            // 尝试获取pair地址
            (success, pairBytes) = factoryV2.staticcall(
                abi.encodeWithSignature("allPairs(uint256)", fromIndex + i)
            );
            if (!success || pairBytes.length != 32) break;
            
            address pair = abi.decode(pairBytes, (address));
            if (pair == address(0)) {
                validCount++;
                continue;
            }
            
            // 获取token0
            (success, pairBytes) = pair.staticcall(abi.encodeWithSignature("token0()"));
            if (!success || pairBytes.length != 32) {
                validCount++;
                continue;
            }
            address token0 = abi.decode(pairBytes, (address));
            
            // 获取token1
            (success, pairBytes) = pair.staticcall(abi.encodeWithSignature("token1()"));
            if (!success || pairBytes.length != 32) {
                validCount++;
                continue;
            }
            address token1 = abi.decode(pairBytes, (address));
            
            // 获取reserves
            (success, pairBytes) = pair.staticcall(abi.encodeWithSignature("getReserves()"));
            if (!success) {
                validCount++;
                continue;
            }
            
            (uint112 reserve0, uint112 reserve1, uint32 lastTime) = abi.decode(pairBytes, (uint112,uint112,uint32));
            
            allPairs[validCount++] = Pair(pair, token0, token1, reserve0, reserve1, lastTime);
        }
        
        // 只返回有效数据
        validPairs = new Pair[](validCount);
        for (uint16 j = 0; j < validCount; j++) {
            validPairs[j] = allPairs[j];
        }
        
        return validPairs;
    }

    function queryV2Pairs(address[] memory pairs) external view returns(uint112[] memory allReserve0, uint112[] memory allReserve1, uint32[] memory allLastTime) {
        allReserve0 = new uint112[](pairs.length);
        allReserve1 = new uint112[](pairs.length);
        allLastTime = new uint32[](pairs.length);
        for (uint16 i = 0; i < pairs.length; i++) {
            // UniswapV2Pair uniPair = UniswapV2Pair(pairs[i]);
            // (uint112 reserve0, uint112 reserve1,uint32 lastTime) = uniPair.getReserves();
            (bool success, bytes memory pairBytes) = pairs[i].staticcall(
                abi.encodeWithSignature("getReserves()")
            );
            if (!success) {
                continue;
            }
            (uint112 reserve0, uint112 reserve1,uint32 lastTime) = abi.decode(pairBytes, (uint112,uint112,uint32));

            allReserve0[i] = reserve0;
            allReserve1[i] = reserve1;
            allLastTime[i] = lastTime;
        }
        return (allReserve0, allReserve1, allLastTime);
    }

    function queryV3NewPositions(UniswapV3Factory factoryV3, address positionManagerV3, uint32 fromIndex, uint16 count) external view returns(Position[] memory positions) {
        positions = new Position[](count);
        for (uint16 i = 0; i < count; i++) {
            // (, , address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, , , , ) = positionManagerV3.positions(fromIndex + i);
            (bool success, bytes memory pairBytes) = positionManagerV3.staticcall(
                abi.encodeWithSignature("positions(uint256)", fromIndex + i)
            );
            if (!success) {
                continue;
            }
            (, , address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, , , , ) = abi.decode(pairBytes, (uint96, address, address, address, uint24,int24, int24, uint128, uint256, uint256, uint128, uint128));

            address pool = factoryV3.getPool(token0, token1, fee);
            UniswapV3Pool poolV3 = UniswapV3Pool(pool);
            positions[i] = Position(pool, token0, token1, fee, tickLower, tickUpper, liquidity, poolV3.tickSpacing());
        }
        return positions;
    }

    function queryV3Positions(address positionManagerV3, uint32[] memory positionIds) external view returns(uint128[] memory liquiditys) {
        liquiditys = new uint128[](positionIds.length);
        for (uint16 i = 0; i < positionIds.length; i++) {
            (bool success, bytes memory pairBytes) = positionManagerV3.staticcall(
                abi.encodeWithSignature("positions(uint256)", positionIds[i])
            );
            if (!success) {
                continue;
            }
            (, , , , , , , uint128 liquidity, , , , ) = abi.decode(pairBytes, (uint96, address, address, address, uint24,int24, int24, uint128, uint256, uint256, uint128, uint128));

            liquiditys[i] = liquidity;
        }
        return (liquiditys);
    }

    function queryV3Reserve(address[] memory pairs) external view returns(uint256[] memory allReserve0, uint256[] memory allReserve1) {
        allReserve0 = new uint256[](pairs.length);
        allReserve1 = new uint256[](pairs.length);
        bool success;
        bytes memory data;
        for (uint256 i = 0; i < pairs.length; i++) {
            UniswapV3Pool pool = UniswapV3Pool(pairs[i]);
            address token0 = pool.token0();
            address token1 = pool.token1();
            
            // 查询token0余额
            (success, data) = token0.staticcall(
                abi.encodeWithSignature("balanceOf(address)", pairs[i])
            );
            allReserve0[i] = success && data.length == 32 ? abi.decode(data, (uint256)) : 0;
            
            // 查询token1余额
            (success, data) = token1.staticcall(
                abi.encodeWithSignature("balanceOf(address)", pairs[i])
            );
            allReserve1[i] = success && data.length == 32 ? abi.decode(data, (uint256)) : 0;
        }
        
        return (allReserve0, allReserve1);
    }

    function queryV3Slot(address[] memory pools) external view returns(uint160[] memory prices, int24[] memory ticks) {
        prices = new uint160[](pools.length);
        ticks = new int24[](pools.length);
        for (uint16 i = 0; i < pools.length; i++) {
            UniswapV3Pool pool = UniswapV3Pool(pools[i]);
            (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
            prices[i] = sqrtPriceX96;
            ticks[i] = tick;
        }
        return (prices, ticks);
    }

    function queryV3SlotEx(address[] memory pools) external view returns(uint160[] memory prices, int24[] memory ticks) {
        prices = new uint160[](pools.length);
        ticks = new int24[](pools.length);
        for (uint16 i = 0; i < pools.length; i++) {
            UniswapV3PoolEx pool = UniswapV3PoolEx(pools[i]);
            (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
            prices[i] = sqrtPriceX96;
            ticks[i] = tick;
        }
        return (prices, ticks);
    }

    function queryCurveNewPools(MetaRegistry metaRegistry, uint32 fromIndex, uint16 count) external view returns(CurvePool[] memory pools) {
        pools = new CurvePool[](count);
        for (uint16 i = 0; i < count; i++) {
            address pool = metaRegistry.pool_list(fromIndex + i);
            if (pool == address(0x0)) {
                break;
            }
            address[8] memory coins = metaRegistry.get_coins(pool);
            uint256[8] memory balances = metaRegistry.get_balances(pool);
            uint256[10] memory fees = metaRegistry.get_fees(pool);
            uint256[20] memory params = metaRegistry.get_pool_params(pool);
            bool registered = metaRegistry.is_registered(pool);
            pools[i] = CurvePool(pool, coins, balances, uint64(params[0]), fees, registered);
        }
        return pools;
    }

    function queryCurveNewPools(MetaRegistry metaRegistry, address[] memory pools) external view returns(CurvePoolUpdate[] memory updatedPools) {
        updatedPools = new CurvePoolUpdate[](pools.length);
        for (uint16 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            uint256[8] memory balances = metaRegistry.get_balances(pool);
            uint256[20] memory params = metaRegistry.get_pool_params(pool);
            bool registered = metaRegistry.is_registered(pool);
            updatedPools[i] = CurvePoolUpdate(balances, uint64(params[0]), registered);
        }
        return updatedPools;
    }
    function decodeString(bytes memory data) public pure returns (string memory) {
        return abi.decode(data, (string));
    }
    function queryTokens(address[] memory addrs) external view returns (Token[] memory tokens) {
        tokens = new Token[](addrs.length);

        for (uint16 i = 0; i < addrs.length; i++) {
            address tokenAddr = addrs[i];
            uint256 supply = 0;
            uint8 decimals = 0;
            string memory name = "";
            string memory symbol = "";

            // totalSupply()
            (bool success, bytes memory result) = tokenAddr.staticcall{
                gas: 10_000
            }(
                abi.encodeWithSignature("totalSupply()")
            );
            if (success && result.length == 32) {
                supply = abi.decode(result, (uint256));
            } else {
                tokens[i] = Token(0, 0, "", "", true);
                continue;
            }

            // decimals()
            (success, result) = tokenAddr.staticcall{
                gas: 5_000
            }(
                abi.encodeWithSignature("decimals()")
            );
            if (success && result.length == 1) {
                decimals = abi.decode(result, (uint8));
            } else if (success && result.length == 4) {
                decimals = uint8(abi.decode(result, (uint32)));
            } else if (success && result.length == 32) {
                decimals = uint8(abi.decode(result, (uint256)));
            } else {
                tokens[i] = Token(supply, 0, "", "", true);
                continue;
            }

            // name()
            (success, result) = tokenAddr.staticcall{
                gas: 5_000
            }(
                abi.encodeWithSignature("name()")
            );
            if (success && result.length > 0) {
                // string ABI: offset (32 bytes) + length (32 bytes) + data
                // name = abi.decode(result, (string));
                try this.decodeString(result) returns (string memory decoded) {
                    name = decoded;
                } catch {
                    name = "";
                }
            } else {
                tokens[i] = Token(supply, decimals, "", "", true);
                continue;
            }

            // symbol()
            (success, result) = tokenAddr.staticcall{
                gas: 5_000
            }(
                abi.encodeWithSignature("symbol()")
            );
            if (success && result.length > 0) {
                // symbol = abi.decode(result, (string));
                try this.decodeString(result) returns (string memory decoded) {
                    symbol = decoded;
                } catch {
                    symbol = "";
                }
            } else {
                tokens[i] = Token(supply, decimals, name, "", true);
                continue;
            }

            tokens[i] = Token(supply, decimals, name, symbol, false);
        }

        return tokens;
    }
}
