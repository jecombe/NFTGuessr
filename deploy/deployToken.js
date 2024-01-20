const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", [
    "0xf1E1676e6222644FED1327D5213E6ac45D7E9FEA",
    "0x766C21f861A35A38cdB716b9cfCcd47F06b21590",
  ]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
