const main = async () => {
  const deployedContract = await ethers.deployContract("GeoSpace", ["0xefAaB7D4Cd249569f883A491609ccdB3D123Fec3"]);

  await deployedContract.waitForDeployment();

  console.log("GeoSpace Contract Address:", await deployedContract.getAddress());
};
main();
