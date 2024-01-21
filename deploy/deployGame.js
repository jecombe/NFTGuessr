const main = async () => {
  const deployedContract = await ethers.deployContract("Game", ["0x85211295749FBa23b395ba59bCC4921E26FCb885"]);

  await deployedContract.waitForDeployment();

  console.log("Game Contract Address:", await deployedContract.getAddress());
};
main();
