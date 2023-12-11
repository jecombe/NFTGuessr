const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x5eF2156Ca23067E2C16dcE8461C63d94A8bEc84f"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
