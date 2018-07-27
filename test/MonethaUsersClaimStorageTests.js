import { advanceBlock } from "./helpers/advanceToBlock";
import log from "./helpers/logger";
import Revert from "./helpers/VMExceptionRevert";

const BigNumber = web3.BigNumber;
const should = require("chai")
  .use(require("chai-as-promised"))
  .use(require("chai-bignumber")(BigNumber))
  .should();

const MonethaUserClaimStorage = artifacts.require("MonethaUsersClaimStorage");

contract("MonethaUsersClaimStorage", function (accounts) {
  const TOKENS = 5;
  let monethaUserClaimStorage;

  beforeEach(async function () {
    monethaUserClaimStorage = await MonethaUserClaimStorage.new();

    advanceBlock();
  });

  it("should set owner address correctly", async function () {
    (await monethaUserClaimStorage.owner()).should.be.equal(accounts[0]);
  });

  describe("updateUserClaim", function () {
    it("should update claim token for the user correctly", async function () {
      const tx = await monethaUserClaimStorage.updateUserClaim(
        accounts[0],
        TOKENS,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens.toNumber().should.be.equal(TOKENS);

      //CHECKING EVENTS
      const event = tx.logs.find(e => e.event === "UpdatedClaim");

      should.exist(event);
      event.args._userAddress.should.equal(accounts[0]);
      event.args._claimedTokens.toNumber().should.equal(TOKENS);
      event.args._isDeleted.should.equal(false);
    });

    it("should not update claim token for the user by other accounts", async function () {
      await monethaUserClaimStorage
        .updateUserClaim(accounts[1], TOKENS, {
          from: accounts[1]
        })
        .should.be.rejectedWith(Revert);
    });
  });

  describe("deleteUserClaim", function () {
    it("should delete token claim of the user", async function () {
      await monethaUserClaimStorage.updateUserClaim(
        accounts[0],
        TOKENS,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens.toNumber().should.be.equal(TOKENS);

      const tx = await monethaUserClaimStorage.deleteUserClaim(
        accounts[0],
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens1 = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens1.toNumber().should.be.equal(0);

      //  CHECKING EVENTS
      const event = tx.logs.find(e => e.event === "DeletedClaim");

      should.exist(event);
      event.args._userAddress.should.equal(accounts[0]);
      event.args._unclaimedTokens.toNumber().should.equal(0);
      event.args._isDeleted.should.equal(true);
    });

    it("should not delete token claim of the user by other accounts", async function () {
      await monethaUserClaimStorage.updateUserClaim(
        accounts[0],
        TOKENS,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      const claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[0]);
      claimedTokens.toNumber().should.be.equal(TOKENS);

      await monethaUserClaimStorage.deleteUserClaim(
        accounts[1],
        {
          from: accounts[1]
        }
      ).should.be.rejectedWith(Revert);

    });

  });

  describe("updateUserClaimInBulk", function () {
    it("should update token claim for the user in bulk", async function () {
      const tx = await monethaUserClaimStorage.updateUserClaimInBulk(
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

      //CHECKING EVENTS
      for (let i = 0; i < 10; i++) {
        let event = tx.logs.find(
          e => e.event === "UpdatedClaim" && e.logIndex === i
        );

        should.exist(event);
        event.args._userAddress.should.equal(accounts[i]);
        event.args._claimedTokens.toNumber().should.equal(TOKENS);
        event.args._isDeleted.should.equal(false);
      }
     
    });

    it("should not update token claim for the user in bulk by other accounts", async function () {
      await monethaUserClaimStorage
        .updateUserClaimInBulk([accounts[1]], [TOKENS], {
          from: accounts[1]
        })
        .should.be.rejectedWith(Revert);

    });
  });

  describe("deleteUserClaimInBulk", function () {
    it("should delete token claim of the user in bulk", async function () {
      await monethaUserClaimStorage.updateUserClaimInBulk(
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

      for (let i=0; i<10; i++) {
        let claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[i]);
        claimedTokens.toNumber().should.be.equal(TOKENS);
      }

      const tx = await monethaUserClaimStorage.deleteUserClaimInBulk(
        accounts,
        {
          from: accounts[0]
        }
      ).should.be.fulfilled;

      for (let i=0; i<10; i++) {
        let claimedTokens = await monethaUserClaimStorage.claimedTokens(accounts[i]);
        claimedTokens.toNumber().should.be.equal(0);
      }

      //CHECKING EVENTS
      for (let i=0; i<10; i++) {
        let event = tx.logs.find(
          e => e.event === "DeletedClaim" && e.logIndex === i
        );

        should.exist(event);
        event.args._userAddress.should.equal(accounts[i]);
        event.args._unclaimedTokens.toNumber().should.equal(0);
        event.args._isDeleted.should.equal(true);
      }
    });

    it("should not delete token claim of the user in bulk by other accounts", async function () {
      await monethaUserClaimStorage.updateUserClaimInBulk(
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

      await monethaUserClaimStorage.deleteUserClaimInBulk(
        accounts,
        {
          from: accounts[1]
        }
      ).should.be.rejectedWith(Revert);
    });
  });
});
