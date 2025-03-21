import { BigInt, Bytes, dataSource } from "@graphprotocol/graph-ts";
import {
  BetPlaced as BetPlacedEvent,
  BetWithdrawal as BetWithdrawalEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  PayoutClaimed as PayoutClaimedEvent,
  PoolClosed as PoolClosedEvent,
  PoolCreated as PoolCreatedEvent,
  Withdrawal as WithdrawalEvent,
} from "../generated/BettingContract/BettingContract";
import {
  Bet,
  BetPlaced,
  BetWithdrawal,
  OwnershipTransferred,
  PayoutClaimed,
  Pool,
  PoolClosed,
  PoolCreated,
  Withdrawal,
} from "../generated/schema";

// @ts-expect-error-next-line
const chainIdToNetworkName = (networkName: string): i32 => {
  if (networkName == "base-sepolia") return 84532;
  if (networkName == "base") return 8453;
  if (networkName == "mainnet") return 1;
  if (networkName == "sepolia") return 11155111;
  if (networkName == "arbitrum-sepolia") return 421614;
  if (networkName == "arbitrum") return 42161;
  if (networkName == "optimism-sepolia") return 111550111;
  if (networkName == "optimism") return 10;
  if (networkName == "scroll-sepolia") return 534351;
  if (networkName == "scroll") return 534352;

  throw new Error(`Network ${networkName} not supported`);
};

export function handleBetPlaced(event: BetPlacedEvent): void {
  const betId = event.params.betId.toString();
  const poolId = event.params.poolId.toString();

  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  // Create BetPlaced entity
  const entity = new BetPlaced(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.betId = event.params.betId;
  entity.poolId = event.params.poolId;
  entity.user = event.params.user;
  entity.optionIndex = event.params.optionIndex;
  entity.amount = event.params.amount;
  entity.tokenType = event.params.tokenType;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  // Create or update Bet entity
  let bet = Bet.load(betId);
  if (bet == null) {
    bet = new Bet(betId);
    bet.betId = event.params.betId;
    bet.user = event.params.user;
    bet.option = event.params.optionIndex;
    bet.amount = event.params.amount;
    bet.poolId = event.params.poolId;
    bet.createdAt = event.block.timestamp;
    bet.updatedAt = event.block.timestamp;
    bet.isWithdrawn = false;
    bet.tokenType = event.params.tokenType == 0 ? "USDC" : "POINTS";
    bet.pool = poolId;
    bet.blockNumber = event.block.number;
    bet.blockTimestamp = event.block.timestamp;
    bet.transactionHash = event.transaction.hash;
    bet.chainName = networkName;
    bet.chainId = BigInt.fromI32(chainId);
  } else {
    // Update existing bet (in case of adding to bet amount)
    bet.amount = bet.amount.plus(event.params.amount);
    bet.updatedAt = event.block.timestamp;
  }

  // Update Pool totals and timestamps
  const pool = Pool.load(poolId);
  if (pool == null) {
    throw new Error(`Pool not found for id: ${poolId}`);
  }

  // Update the appropriate bet totals based on token type
  if (event.params.tokenType == 0) {
    // USDC
    const usdcBetTotals = pool.usdcBetTotals;
    usdcBetTotals[event.params.optionIndex.toI32()] = usdcBetTotals[
      event.params.optionIndex.toI32()
    ].plus(event.params.amount);
    pool.usdcBetTotals = usdcBetTotals;
    pool.usdcVolume = pool.usdcVolume.plus(event.params.amount);
  } else {
    // POINTS
    const pointsBetTotals = pool.pointsBetTotals;
    pointsBetTotals[event.params.optionIndex.toI32()] = pointsBetTotals[
      event.params.optionIndex.toI32()
    ].plus(event.params.amount);
    pool.pointsBetTotals = pointsBetTotals;
    pool.pointsVolume = pool.pointsVolume.plus(event.params.amount);
  }

  // Update lastUpdated timestamps
  pool.lastUpdatedBlockNumber = event.block.number;
  pool.lastUpdatedBlockTimestamp = event.block.timestamp;
  pool.lastUpdatedTransactionHash = event.transaction.hash;

  pool.save();
  bet.save();
  entity.save();
}

export function handleBetWithdrawal(event: BetWithdrawalEvent): void {
  const betId = event.params.betId.toString();

  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  const entity = new BetWithdrawal(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.user = event.params.user;
  entity.betId = event.params.betId;
  entity.amount = event.params.amount;
  entity.tokenType = event.params.tokenType;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  // Update bet as withdrawn
  const bet = Bet.load(betId);
  if (bet != null) {
    bet.isWithdrawn = true;
    bet.save();
  }

  entity.save();
}

export function handleWithdrawal(event: WithdrawalEvent): void {
  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  const entity = new Withdrawal(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.user = event.params.user;
  entity.amount = event.params.amount;
  entity.tokenType = event.params.tokenType;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  entity.save();
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  const entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  entity.save();
}

export function handlePayoutClaimed(event: PayoutClaimedEvent): void {
  const betId = event.params.betId.toString();
  const poolId = event.params.poolId.toString();

  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  const entity = new PayoutClaimed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.betId = event.params.betId;
  entity.poolId = event.params.poolId;
  entity.user = event.params.user;
  entity.amount = event.params.amount;
  entity.tokenType = event.params.tokenType;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);
  entity.bet = betId;
  entity.pool = poolId;

  // Update bet as paid out
  const bet = Bet.load(betId);
  if (bet != null) {
    bet.isWithdrawn = true;
    bet.save();
  }

  entity.save();
}

export function handlePoolClosed(event: PoolClosedEvent): void {
  const poolId = event.params.poolId.toString();

  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  const entity = new PoolClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.poolId = event.params.poolId;
  entity.selectedOption = event.params.selectedOption;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  // Update Pool status and timestamps
  const pool = Pool.load(poolId);
  if (pool != null) {
    pool.winningOption = event.params.selectedOption;
    pool.status = "GRADED";

    // Update graded timestamps
    pool.gradedBlockNumber = event.block.number;
    pool.gradedBlockTimestamp = event.block.timestamp;
    pool.gradedTransactionHash = event.transaction.hash;

    pool.save();
  }

  entity.save();
}

export function handlePoolCreated(event: PoolCreatedEvent): void {
  const poolId = event.params.poolId.toString();

  const networkName = dataSource.network();
  const chainId = chainIdToNetworkName(networkName);

  // Create PoolCreated entity
  const entity = new PoolCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.poolId = event.params.poolId;
  entity.params_question = event.params.params.question;
  entity.params_options = event.params.params.options;
  entity.params_betsCloseAt = event.params.params.betsCloseAt;
  entity.params_closureCriteria = event.params.params.closureCriteria;
  entity.params_closureInstructions = event.params.params.closureInstructions;
  entity.params_originalTruthSocialPostId =
    event.params.params.originalTruthSocialPostId;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.chainName = networkName;
  entity.chainId = BigInt.fromI32(chainId);

  // Create Pool entity
  const pool = new Pool(poolId);
  pool.poolId = event.params.poolId;
  pool.question = event.params.params.question;
  pool.options = event.params.params.options;
  pool.usdcBetTotals = [BigInt.fromI32(0), BigInt.fromI32(0)];
  pool.pointsBetTotals = [BigInt.fromI32(0), BigInt.fromI32(0)];
  pool.usdcVolume = BigInt.fromI32(0);
  pool.pointsVolume = BigInt.fromI32(0);
  pool.betsCloseAt = event.params.params.betsCloseAt;
  pool.winningOption = BigInt.fromI32(0);
  pool.status = "PENDING";
  pool.isDraw = false;
  pool.createdAt = event.block.timestamp;
  pool.closureCriteria = event.params.params.closureCriteria;
  pool.closureInstructions = event.params.params.closureInstructions;
  pool.originalTruthSocialPostId =
    event.params.params.originalTruthSocialPostId;
  pool.chainName = networkName;
  pool.chainId = BigInt.fromI32(chainId);

  // Set initial timestamps
  pool.createdBlockNumber = event.block.number;
  pool.createdBlockTimestamp = event.block.timestamp;
  pool.createdTransactionHash = event.transaction.hash;

  // Initialize lastUpdated timestamps to match created timestamps
  pool.lastUpdatedBlockNumber = event.block.number;
  pool.lastUpdatedBlockTimestamp = event.block.timestamp;
  pool.lastUpdatedTransactionHash = event.transaction.hash;

  // Initialize graded timestamps to zero
  pool.gradedBlockNumber = BigInt.fromI32(0);
  pool.gradedBlockTimestamp = BigInt.fromI32(0);
  pool.gradedTransactionHash = Bytes.empty();

  pool.save();
  entity.save();
}
