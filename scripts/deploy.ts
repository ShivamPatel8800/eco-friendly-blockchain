import { ethers } from "hardhat";

async function main() {
  console.log("╔══════════════════════════════════════════════════╗");
  console.log("║  Eco-Friendly Consensus Mechanism — Deployment   ║");
  console.log("╚══════════════════════════════════════════════════╝\n");

  const [deployer, validator1, validator2] = await ethers.getSigners();

  console.log("Deployer  :", deployer.address);
  if (validator1) console.log("Validator1:", validator1.address);
  if (validator2) console.log("Validator2:", validator2.address);
  console.log("");

  // ── 1. Deploy EcoToken ──────────────────────────────────────────────────────
  console.log("► Deploying EcoToken...");
  const EcoToken = await ethers.getContractFactory("EcoToken");
  const ecoToken = await EcoToken.deploy(deployer.address);
  await ecoToken.waitForDeployment();
  const tokenAddress = await ecoToken.getAddress();
  console.log("  ✓ EcoToken  →", tokenAddress);

  // ── 2. Deploy EcoTracker (quorum = 2) ──────────────────────────────────────
  const QUORUM = 2n;
  console.log(`\n► Deploying EcoTracker (quorum = ${QUORUM})...`);
  const EcoTracker = await ethers.getContractFactory("EcoTracker");
  const ecoTracker = await EcoTracker.deploy(tokenAddress, deployer.address, QUORUM);
  await ecoTracker.waitForDeployment();
  const trackerAddress = await ecoTracker.getAddress();
  console.log("  ✓ EcoTracker →", trackerAddress);

  // ── 3. Grant DISTRIBUTOR_ROLE to EcoTracker ─────────────────────────────────
  console.log("\n► Granting DISTRIBUTOR_ROLE to EcoTracker...");
  const DISTRIBUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DISTRIBUTOR_ROLE"));
  const tx1 = await ecoToken.grantRole(DISTRIBUTOR_ROLE, trackerAddress);
  await tx1.wait();
  console.log("  ✓ Role granted");

  // ── 4. Add extra validators (if accounts available) ─────────────────────────
  const VALIDATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("VALIDATOR_ROLE"));

  if (validator1) {
    console.log("\n► Adding validator1 as VALIDATOR_ROLE...");
    const tx2 = await ecoTracker.grantRole(VALIDATOR_ROLE, validator1.address);
    await tx2.wait();
    console.log("  ✓ validator1 granted VALIDATOR_ROLE");
  }

  if (validator2) {
    console.log("\n► Adding validator2 as VALIDATOR_ROLE...");
    const tx3 = await ecoTracker.grantRole(VALIDATOR_ROLE, validator2.address);
    await tx3.wait();
    console.log("  ✓ validator2 granted VALIDATOR_ROLE");
  }

  // ── Summary ─────────────────────────────────────────────────────────────────
  console.log("\n╔══════════════════════════════════════════════════╗");
  console.log("║                Deployment complete               ║");
  console.log("╠══════════════════════════════════════════════════╣");
  console.log(`║  EcoToken   : ${tokenAddress}  ║`);
  console.log(`║  EcoTracker : ${trackerAddress}  ║`);
  console.log(`║  Quorum     : ${QUORUM} validators                         ║`);
  console.log("╚══════════════════════════════════════════════════╝");

  // ── Persist addresses for the verify script ──────────────────────────────────
  const fs = await import("fs");
  const deployment = {
    network: (await ethers.provider.getNetwork()).name,
    deployedAt: new Date().toISOString(),
    contracts: {
      EcoToken:   tokenAddress,
      EcoTracker: trackerAddress,
    },
    config: { quorum: Number(QUORUM) },
  };
  fs.writeFileSync(
    "deployment.json",
    JSON.stringify(deployment, null, 2)
  );
  console.log("\n  Saved → deployment.json");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
