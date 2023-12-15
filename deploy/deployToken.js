const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xFfd7e1423eea7B68c61539Fdc598d4af131cC31E"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
