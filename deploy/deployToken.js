const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xa3cA3069f12d06F3AE75842161871211A7347071"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
