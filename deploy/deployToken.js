const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0x9E4211844f2fe4478Fa576639025c509F1D65CDB",
    "0x90474cA6E0D0DA48420Ebd7e1A9ec56dfB088616",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
