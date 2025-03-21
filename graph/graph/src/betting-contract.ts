import {
  BetPlaced as BetPlacedEvent,
  BetWithdrawal as BetWithdrawalEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  PayoutClaimed as PayoutClaimedEvent,
  PoolClosed as PoolClosedEvent,
  PoolCreated as PoolCreatedEvent,
  Withdrawal as WithdrawalEvent
} from "../generated/BettingContract/BettingContract"
import {
  BetPlaced,
  BetWithdrawal,
  OwnershipTransferred,
  PayoutClaimed,
  PoolClosed,
  PoolCreated,
  Withdrawal
} from "../generated/schema"

export function handleBetPlaced(event: BetPlacedEvent): void {
  let entity = new BetPlaced(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.betId = event.params.betId
  entity.poolId = event.params.poolId
  entity.user = event.params.user
  entity.optionIndex = event.params.optionIndex
  entity.amount = event.params.amount
  entity.tokenType = event.params.tokenType

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleBetWithdrawal(event: BetWithdrawalEvent): void {
  let entity = new BetWithdrawal(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.user = event.params.user
  entity.betId = event.params.betId
  entity.amount = event.params.amount
  entity.tokenType = event.params.tokenType

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePayoutClaimed(event: PayoutClaimedEvent): void {
  let entity = new PayoutClaimed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.betId = event.params.betId
  entity.poolId = event.params.poolId
  entity.user = event.params.user
  entity.amount = event.params.amount
  entity.tokenType = event.params.tokenType

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePoolClosed(event: PoolClosedEvent): void {
  let entity = new PoolClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.poolId = event.params.poolId
  entity.selectedOption = event.params.selectedOption

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePoolCreated(event: PoolCreatedEvent): void {
  let entity = new PoolCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.poolId = event.params.poolId
  entity.params_question = event.params.params.question
  entity.params_options = event.params.params.options
  entity.params_betsCloseAt = event.params.params.betsCloseAt
  entity.params_closureCriteria = event.params.params.closureCriteria
  entity.params_closureInstructions = event.params.params.closureInstructions
  entity.params_originalTruthSocialPostId =
    event.params.params.originalTruthSocialPostId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleWithdrawal(event: WithdrawalEvent): void {
  let entity = new Withdrawal(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.user = event.params.user
  entity.amount = event.params.amount
  entity.tokenType = event.params.tokenType

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
