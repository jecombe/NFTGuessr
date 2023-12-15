const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x9CFE107B6D8a30B64ca3221cb6c4EAB9607F3F63"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
