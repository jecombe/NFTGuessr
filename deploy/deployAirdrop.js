const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0xf1E1676e6222644FED1327D5213E6ac45D7E9FEA"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
