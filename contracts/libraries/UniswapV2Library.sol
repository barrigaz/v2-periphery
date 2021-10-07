// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import '../../../v2-core/contracts/interfaces/IUniswapV2Pair.sol';

library UniswapV2Library {

    uint private constant FEE_SWAP_PRECISION = 10**5;

    struct Path {
        address tokenIn;
        address tokenOut;
        uint120 feeSwap;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(tokenA != address(0), 'UniswapV2Library: ZERO_ADDRESS');
        return (tokenA, tokenB);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB, uint feeSwap) internal pure returns (address pair) {
        (tokenA, tokenB) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(tokenA, tokenB, feeSwap)),
                hex'0d00300382b498ba254abc75b8316fbc536c0aea12ac70820996a951da929c74', // init code hash
                tokenA, tokenB, feeSwap
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB, uint feeSwap) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        IUniswapV2Pair.Reserves memory reserves = IUniswapV2Pair(pairFor(factory, tokenA, tokenB, feeSwap)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserves.reserve0, reserves.reserve1) : (reserves.reserve1, reserves.reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint feeSwap) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * (FEE_SWAP_PRECISION - feeSwap);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * FEE_SWAP_PRECISION + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint feeSwap) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * FEE_SWAP_PRECISION;
        uint denominator = (reserveOut - amountOut) * (FEE_SWAP_PRECISION - feeSwap);
        amountIn = (numerator / denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, Path[] memory path) internal view returns (uint[] memory amounts) {
        amounts = new uint[](path.length + 1);
        amounts[0] = amountIn;
        for (uint i; i < path.length; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i].tokenIn, path[i].tokenOut, path[i].feeSwap);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, path[i].feeSwap);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, Path[] memory path) internal view returns (uint[] memory amounts) {
        amounts = new uint[](path.length + 1);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i].tokenIn, path[i].tokenOut, path[i].feeSwap);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, path[i].feeSwap);
        }
    }
}
