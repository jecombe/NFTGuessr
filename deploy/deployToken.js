const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xA2732719a7B4b78e00631A9bb63098f1982a9aE9"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
