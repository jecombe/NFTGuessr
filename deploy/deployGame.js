const main = async () => {
  const deployedContract = await ethers.deployContract("GeoSpace", ["0x9E4211844f2fe4478Fa576639025c509F1D65CDB"]);

  await deployedContract.waitForDeployment();

  console.log("GeoSpace Contract Address:", await deployedContract.getAddress());
};
main();
