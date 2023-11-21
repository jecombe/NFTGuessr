const main = async () => {
  const deployedContract = await ethers.deployContract("NftGuessrSave");

  await deployedContract.waitForDeployment();

  console.log("NftGuessrSave Contract Address:", await deployedContract.getAddress());
};
main();
