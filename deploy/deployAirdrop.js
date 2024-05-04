const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0xbEd869A588bD10C17Ee77a87Ee495a7D32C73836"]);

  await deployedContract.waitForDeployment();

  console.log("Airdrop Contract Address:", await deployedContract.getAddress());
};
main();
