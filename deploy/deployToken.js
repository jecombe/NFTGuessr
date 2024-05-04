const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0xbEd869A588bD10C17Ee77a87Ee495a7D32C73836",
    "0x9023f009A93882fd75480cd1BABaCf1bBc47970A",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
