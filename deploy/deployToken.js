const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xE5B24f93cb2B69b794F55E78e328A97e80aad677"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
