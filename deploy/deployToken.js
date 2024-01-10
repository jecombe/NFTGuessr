const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x7736E214C304fF2bdEF83938BDC9c431B55509d1"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
