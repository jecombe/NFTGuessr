const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0xefAaB7D4Cd249569f883A491609ccdB3D123Fec3",
    "0xB754Bb56c49f3bc618512E28B01f633963F865aC",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
