// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

abstract contract UniswapV2Factory {
    function allPairs(uint256 index) external view virtual returns(address);
}
abstract contract UniswapV2Pair {
    function token0() external view virtual returns(address);
    function token1() external view virtual returns(address);
    function getReserves() external view virtual returns(uint112, uint112, uint32);
}

abstract contract UniswapV3PositionManager {
    function positions(uint256 tokenId) external view virtual returns(uint96 nonce, address operator, address token0, address token1, uint24 fee,
        int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1);
}

abstract contract UniswapV3Factory {
    function getPool(address token0, address token1, uint24 fee) external view virtual returns(address pool);
}

contract UniswapTool {
    // V2 Factory
    UniswapV2Factory factoryV2 = UniswapV2Factory(0x733E88f248b742db6C14C0b1713Af5AD7fDd59D0);
    // V3 NonfungiblePositionManager
    UniswapV3PositionManager positionManagerV3 = UniswapV3PositionManager(0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7);
    // V3 Factory
    UniswapV3Factory factoryV3 = UniswapV3Factory(0x961235a9020B05C44DF1026D956D1F4D78014276);

    struct Position {
        address addr;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    struct Pair {
        address addr;
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint32 lastTime;
    }

    function queryV2NewPairs(uint32 fromIndex, uint16 count) external view returns(Pair[] memory allPairs) {
        allPairs = new Pair[](count);
        for (uint16 i = 0; i < count; i++) {
            address pair = factoryV2.allPairs(fromIndex + i);
            if (pair == address(0)) {
                break;
            }
            UniswapV2Pair uniPair = UniswapV2Pair(pair);
            // token 0
            address token0 = uniPair.token0();
            // token 1
            address token1 = uniPair.token1();
            // reserve
            (uint112 reserve0, uint112 reserve1,uint32 lastTime) = uniPair.getReserves();
            allPairs[i] = Pair(pair, token0, token1, reserve0, reserve1, lastTime);
        }
        return (allPairs);
    }

    function queryV2Pairs(address[] memory pairs) external view returns(uint112[] memory allReserve0, uint112[] memory allReserve1, uint32[] memory allLastTime) {
        allReserve0 = new uint112[](pairs.length);
        allReserve1 = new uint112[](pairs.length);
        allLastTime = new uint32[](pairs.length);
        for (uint16 i = 0; i < pairs.length; i++) {
            UniswapV2Pair uniPair = UniswapV2Pair(pairs[i]);
            (uint112 reserve0, uint112 reserve1,uint32 lastTime) = uniPair.getReserves();
            allReserve0[i] = reserve0;
            allReserve1[i] = reserve1;
            allLastTime[i] = lastTime;
        }
        return (allReserve0, allReserve1, allLastTime);
    }

    function queryV3NewPositions(uint32 fromIndex, uint16 count) external view returns(Position[] memory positions) {
        positions = new Position[](count);
        for (uint16 i = 0; i < count; i++) {
            (, , address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, , , , ) = positionManagerV3.positions(fromIndex + i);
            address pool = factoryV3.getPool(token0, token1, fee);
            positions[i] = Position(pool, token0, token1, fee, tickLower, tickUpper, liquidity);
        }
        return (positions);
    }

    function queryV3Positions(uint32[] memory positionIds) external view returns(uint128[] memory liquiditys) {
        liquiditys = new uint128[](positionIds.length);
        for (uint16 i = 0; i < positionIds.length; i++) {
            (, , , , , , , uint128 liquidity, , , , ) = positionManagerV3.positions(positionIds[i]);
            liquiditys[i] = liquidity;
        }
        return (liquiditys);
    }

}
