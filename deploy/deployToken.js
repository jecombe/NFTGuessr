const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xc82039BbaE11C8fa14873f6C5926356487638Fe4"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
