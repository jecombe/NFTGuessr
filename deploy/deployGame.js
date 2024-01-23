const main = async () => {
  const deployedContract = await ethers.deployContract("GeoSpace", ["0xA2494f226C79AcBcbAFDF66A041874146610548d"]);

  await deployedContract.waitForDeployment();

  console.log("GeoSpace Contract Address:", await deployedContract.getAddress());
};
main();
