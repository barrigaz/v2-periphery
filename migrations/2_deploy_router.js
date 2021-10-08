const Router = artifacts.require("UniswapV2Router02");
const factory = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const weth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

module.exports = async(deployer, network, accounts) => {
  await deployer.deploy(Router, factory, weth);
  // const router = await Router.deployed();
};
