const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xC79A9390eFc8f787125e39C38825B0554E1cbd02"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
