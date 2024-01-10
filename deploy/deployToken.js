const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x301C07bBe4f38d06617f450cDb6d261f24abF1Bc"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
