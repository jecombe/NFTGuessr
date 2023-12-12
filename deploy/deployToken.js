const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x3ab7328f121c0618BF114A6eBFCc2690C5983aC6"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
