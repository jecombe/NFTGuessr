const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x71C5136685A972Bc8Ae602e85E536245591D387e"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
