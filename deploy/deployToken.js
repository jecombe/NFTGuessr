const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0x10e6C0DC13cc05Cb73A234e2c1A4E1894f48ba78",
    "0x220fB8B4B3D8512984D7ee93eEC2E2d16Fb45f1f",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
