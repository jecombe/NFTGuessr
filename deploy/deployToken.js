const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0xA2494f226C79AcBcbAFDF66A041874146610548d",
    "0x9E5cf2E317731C8a59FC65e3847284d72cA87096",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
