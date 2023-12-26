const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x87d09bF396aCa1A33f027AbAF5f849AA6D115F2e"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
