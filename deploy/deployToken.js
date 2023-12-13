const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xfba866d23f122f7c0E95CE0cD8261bcA10FB9c97"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
