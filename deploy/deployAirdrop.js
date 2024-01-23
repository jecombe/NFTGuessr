const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0xA2494f226C79AcBcbAFDF66A041874146610548d"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
