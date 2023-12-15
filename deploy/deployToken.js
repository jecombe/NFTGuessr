const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x2163f47c875DcB78Ce6720e32d1bB99074DCCeC2"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
