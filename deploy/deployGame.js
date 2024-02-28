const main = async () => {
  const deployedContract = await ethers.deployContract("GeoSpace", ["0xC2Ac9f6D39a6929D995298C9c16a2af8821DB1F1"]);

  await deployedContract.waitForDeployment();

  console.log("GeoSpace Contract Address:", await deployedContract.getAddress());
};
main();
