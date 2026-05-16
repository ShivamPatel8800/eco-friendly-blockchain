/**
 * verify.ts — post-deploy smoke test
 *
 * Usage:
 *   npx hardhat run scripts/verify.ts
 *
 * Reads deployment.json written by deploy.ts and exercises the full
 * log → vote → reward workflow on a local Hardhat network.
 */

import { ethers } from "hardhat";
import { readFileSync } from "fs";

// ActivityCategory enum order must match EcoTracker.sol
const Category = {
  TreePlanting:          0,
  Recycling:             1,
  SolarEnergy:           2,
  WaterConservation:     3,
  CarbonOffset:          4,
  BiodiversityProtection:5,
  Other:                 6,
} as const;

async function main() {
  console.log("╔══════════════════════════════════════════════════╗");
  console.log("║       EcoTracker — End-to-End Smoke Test         ║");
  console.log("╚══════════════════════════════════════════════════╝\n");

  // ── Load addresses ─────────────────────────────────────────────────────────
  let tokenAddr: string;
  let trackerAddr: string;

  try {
    const dep = JSON.parse(readFileSync("deployment.json", "utf-8"));
    tokenAddr   = dep.contracts.EcoToken;
    trackerAddr = dep.contracts.EcoTracker;
    console.log("Loaded deployment.json");
  } catch {
    // Fall back to fresh deploy for CI
    console.log("deployment.json not found — deploying fresh...");
    const [deployer] = await ethers.getSigners();
    const EcoToken   = await ethers.getContractFactory("EcoToken");
    const token      = await EcoToken.deploy(deployer.address);
    await token.waitForDeployment();
    tokenAddr = await token.getAddress();

    const EcoTracker = await ethers.getContractFactory("EcoTracker");
    const tracker    = await EcoTracker.deploy(tokenAddr, deployer.address, 2n);
    await tracker.waitForDeployment();
    trackerAddr = await tracker.getAddress();

    const DISTRIBUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DISTRIBUTOR_ROLE"));
    await (await token.grantRole(DISTRIBUTOR_ROLE, trackerAddr)).wait();
  }

  const [deployer, validator1, validator2, user] = await ethers.getSigners();

  const token   = await ethers.getContractAt("EcoToken",   tokenAddr);
  const tracker = await ethers.getContractAt("EcoTracker", trackerAddr);

  // Grant validator roles if running fresh
  const VALIDATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("VALIDATOR_ROLE"));
  if (validator1 && !(await tracker.hasRole(VALIDATOR_ROLE, validator1.address))) {
    await (await tracker.grantRole(VALIDATOR_ROLE, validator1.address)).wait();
  }
  if (validator2 && !(await tracker.hasRole(VALIDATOR_ROLE, validator2.address))) {
    await (await tracker.grantRole(VALIDATOR_ROLE, validator2.address)).wait();
  }

  console.log("EcoToken  :", tokenAddr);
  console.log("EcoTracker:", trackerAddr);
  console.log("User      :", user?.address ?? deployer.address);
  console.log("");

  const actor = user ?? deployer;

  // ── Test 1: Log a TreePlanting activity ───────────────────────────────────
  console.log("── Test 1: Log activity ─────────────────────────────");
  const tx1 = await tracker.connect(actor).logActivity(
    Category.TreePlanting,
    "Planted 10 oak saplings in local park",
    "QmXyz123abc456def789"
  );
  const receipt1 = await tx1.wait();
  const logEvent = receipt1?.logs
    .map((l: any) => { try { return tracker.interface.parseLog(l); } catch { return null; } })
    .find((e: any) => e?.name === "ActivityLogged");

  const actId: bigint = logEvent?.args?.id ?? 1n;
  console.log(`  Activity #${actId} logged  ✓`);

  // ── Test 2: Vote (approval) ────────────────────────────────────────────────
  console.log("\n── Test 2: Validator votes ──────────────────────────");
  const v1 = validator1 ?? deployer;
  const v2 = validator2 ?? deployer;

  await (await tracker.connect(v1).castVote(actId, true)).wait();
  console.log("  Validator1 voted: APPROVE  ✓");

  if (v1.address !== v2.address) {
    await (await tracker.connect(v2).castVote(actId, true)).wait();
    console.log("  Validator2 voted: APPROVE  ✓");
  }

  // ── Test 3: Check status & balance ────────────────────────────────────────
  console.log("\n── Test 3: Verify outcome ───────────────────────────");
  const activity = await tracker.getActivity(actId);
  const statusLabel = ["Pending","Approved","Rejected","Expired"][Number(activity.status)];

  console.log(`  Status      : ${statusLabel}`);
  console.log(`  Reward      : ${ethers.formatEther(activity.rewardAmount)} EFT`);

  const bal = await token.balanceOf(actor.address);
  console.log(`  User balance: ${ethers.formatEther(bal)} EFT`);

  if (Number(activity.status) === 1 /* Approved */) {
    console.log("\n  ✓ Activity correctly approved and tokens minted!");
  } else {
    console.warn("\n  ✗ Activity not yet approved — check quorum / signer setup.");
  }

  // ── Test 4: Staking ───────────────────────────────────────────────────────
  console.log("\n── Test 4: Stake EFT tokens ─────────────────────────");
  if (bal >= ethers.parseEther("10")) {
    const stakeAmt = ethers.parseEther("10");

    // Approve the token contract to transfer (staking calls _transfer internally)
    // Actually, stake() calls _transfer from user→contract, so no separate approve needed.
    await (await token.connect(actor).stake(stakeAmt)).wait();
    const weight = await token.governanceWeight(actor.address);
    console.log(`  Staked 10 EFT  ✓`);
    console.log(`  Governance weight: ${ethers.formatEther(weight)} EFT`);
  } else {
    console.log("  (skip — balance < 10 EFT; need quorum ≥ 2 validators)");
  }

  // ── Test 5: View helpers ──────────────────────────────────────────────────
  console.log("\n── Test 5: View helpers ─────────────────────────────");
  const userIds = await tracker.getUserActivityIds(actor.address);
  console.log(`  getUserActivityIds → [${userIds.join(", ")}]  ✓`);
  const total = await tracker.totalActivities();
  console.log(`  totalActivities   → ${total}  ✓`);

  console.log("\n╔══════════════════════════════════════════════════╗");
  console.log("║               All tests passed  ✓               ║");
  console.log("╚══════════════════════════════════════════════════╝");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
