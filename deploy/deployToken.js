const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0x85211295749FBa23b395ba59bCC4921E26FCb885",
    "0x2fD82534c9b66cBE501620f3C7acfCc9881e9129",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
