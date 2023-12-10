const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x88DCe9414eF01B9C94b7Dd79717EE3f117Be0B3d"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
