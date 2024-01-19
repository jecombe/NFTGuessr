const main = async () => {
  const deployedContract = await ethers.deployContract("NftGuessr");

  await deployedContract.waitForDeployment();

  console.log("NftGuessrCpy Contract Address:", await deployedContract.getAddress());
};
main();
