const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0xc74bA1e8C6068c39B68A2c9E1C8e1bAdD25A6D28"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
