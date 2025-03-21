import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address } from "@graphprotocol/graph-ts"
import { BetPlaced } from "../generated/schema"
import { BetPlaced as BetPlacedEvent } from "../generated/BettingContract/BettingContract"
import { handleBetPlaced } from "../src/betting-contract"
import { createBetPlacedEvent } from "./betting-contract-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let betId = BigInt.fromI32(234)
    let poolId = BigInt.fromI32(234)
    let user = Address.fromString("0x0000000000000000000000000000000000000001")
    let optionIndex = BigInt.fromI32(234)
    let amount = BigInt.fromI32(234)
    let tokenType = 123
    let newBetPlacedEvent = createBetPlacedEvent(
      betId,
      poolId,
      user,
      optionIndex,
      amount,
      tokenType
    )
    handleBetPlaced(newBetPlacedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("BetPlaced created and stored", () => {
    assert.entityCount("BetPlaced", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "betId",
      "234"
    )
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "poolId",
      "234"
    )
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "user",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "optionIndex",
      "234"
    )
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "amount",
      "234"
    )
    assert.fieldEquals(
      "BetPlaced",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "tokenType",
      "123"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
