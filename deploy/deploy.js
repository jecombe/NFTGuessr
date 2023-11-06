const main = async () => {
  const deployedContract = await ethers.deployContract("NftGuessr");

  await deployedContract.waitForDeployment();

  console.log("NftGuessr Contract Address:", await deployedContract.getAddress());
};
main();
