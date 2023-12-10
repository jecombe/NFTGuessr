const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xd681b63816C80d4ffA751313d22F8c9E8983F7b1"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
