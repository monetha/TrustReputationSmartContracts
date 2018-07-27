import { advanceBlock } from "./helpers/advanceToBlock";
import log from "./helpers/logger";
import Revert from "./helpers/VMExceptionRevert";

const BigNumber = web3.BigNumber;
const should = require("chai")
  .use(require("chai-as-promised"))
  .use(require("chai-bignumber")(BigNumber))
  .should();

const MonethaUserClaimStorage = artifacts.require("MonethaUsersClaimStorage");
const MonethaUserClaimHandler = artifacts.require("MonethaUsersClaimHandler");

contract("MonethaUsersClaimHandler", function (accounts) {
  const TOKENS = 5;
  let monethaUserClaimStorage;
  let monethaUserClaimHandler;

  beforeEach(async function () {
    monethaUserClaimStorage = await MonethaUserClaimStorage.new();
    monethaUserClaimHandler = await MonethaUserClaimHandler.new(monethaUserClaimStorage.address, { from: accounts[0] });
    await monethaUserClaimStorage.transferOwnership(monethaUserClaimHandler.address);
    advanceBlock();
  });

  it("should set owner address correctly", async function () {
    (await monethaUserClaimHandler.owner()).should.be.equal(accounts[0]);
  });

  describe("claimTokens", function () {
    it("should claim tokens for the user correctly", async function () {
      await monethaUserClaimHandler.claimTokens(accounts[0], TOKENS, { from: accounts[0] }).should.be.fulfilled;

      const claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens.toNumber().should.be.equal(TOKENS);
    });

    it("should not claim tokens for user by other accounts", async function () {
      await monethaUserClaimHandler.claimTokens(accounts[1], TOKENS, { from: accounts[1] }).should.be.rejectedWith(Revert);
    });
  });

  describe("claimTokensInBulk", function () {
    it("should claim tokens for the user in bulk", async function () {
      await monethaUserClaimHandler.claimTokensInBulk(
        accounts,
        [
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
        ],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      for (let i = 0; i < 10; i++) {
        let claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[i]);
        claimedTokens.toNumber().should.be.equal(TOKENS);
      }
    });

    it("should not claim tokens for the user in bulk by other accounts", async function () {
      await monethaUserClaimHandler
        .claimTokensInBulk([accounts[1]], [TOKENS], {
          from: accounts[1]
        })
        .should.be.rejectedWith(Revert);
    });
  });

  describe("deleteAccount", function () {
    it("should delete claimed tokens of the user correctly", async function () {
      await monethaUserClaimHandler.claimTokens(
        accounts[0],
        TOKENS,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens.toNumber().should.be.equal(TOKENS);

      await monethaUserClaimHandler.deleteAccount(
        accounts[0],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens1 = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens1.toNumber().should.be.equal(0);
    });

    it("should no delete user account and tokens by other accounts", async function () {
      await monethaUserClaimHandler.deleteAccount(
        accounts[1],
        {
          from: accounts[1]
        }
      ).should.be.rejectedWith(Revert);
    });
  });

  describe("deleteAccountsInBulk", function () {
    it("should delete claimed tokens of the user in bulk", async function () {
      await monethaUserClaimHandler.claimTokensInBulk(
        accounts,
        [
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
        ],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      for (let i = 0; i < 10; i++) {
        let claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[i]);
        claimedTokens.toNumber().should.be.equal(TOKENS);
      }

      await monethaUserClaimHandler.deleteAccountsInBulk(
        accounts,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      for (let i = 0; i < 10; i++) {
        let claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[i]);
        claimedTokens.toNumber().should.be.equal(0);
      }
    });

    it("should not delete claimed tokens of the user in bulk by other accounts", async function () {
      await monethaUserClaimHandler.claimTokensInBulk(
        accounts,
        [
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
          TOKENS,
        ],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      await monethaUserClaimHandler.deleteAccountsInBulk(
        accounts,
        {
          from: accounts[1]
        }
      ).should.be.rejectedWith(Revert);

    });
  });

  describe("changeOwnerOfMonethaUsersClaimStorage", function () {
    it("should change owner of Monetha User Claim Storage Contract", async function () {
      const tx = await monethaUserClaimHandler.changeOwnerOfMonethaUsersClaimStorage(
        accounts[1],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      (await monethaUserClaimStorage.owner()).should.be.equal(accounts[1]);

      //CHECKING EVENTS
      const event = tx.logs.find(e => e.event === "StorageContractOwnerChanged");

      should.exist(event);
      event.args._newOwner.should.equal(accounts[1]);
    });
    it("should not change owner of Monetha User Claim Storage Contract by others accounts", async function () {
      await monethaUserClaimHandler
        .changeOwnerOfMonethaUsersClaimStorage(accounts[1], {
          from: accounts[1]
        })
        .should.be.rejectedWith(Revert);
    });
  });
});
