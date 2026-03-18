const db = require("../controllers/db");

module.exports = async function (fastify, opts) {
  fastify.get("/members/:bioguide_id", async (request, reply) => {
    const { bioguide_id } = request.params;
    
    if (!/^[A-Z0-9]+$/i.test(bioguide_id)) {
      reply.code(400);
      return { error: "Invalid bioguide ID format" };
    }

    const upperId = bioguide_id.toUpperCase();

    let profile = await db.knex("vote_members")
        .where({ bioguide_id: upperId })
        .select("display_name as name", "party", "state")
        .first();
    
    if (!profile) {
      profile = await db.knex("bill_cosponsors")
        .where({ bioguide_id: upperId })
        .select("full_name as name", "party", "state")
        .first();
    }

    if (!profile) {
      profile = await db.knex("bills")
        .where({ sponsor_bioguide_id: upperId })
        .select("sponsor_name as name", "sponsor_party as party", "sponsor_state as state")
        .first();
    }

    if (!profile) {
      reply.code(404);
      return { error: "Member not found in recent records" };
    }

    const [sponsoredBills, recentVotes, sponsoredCount, cosponsoredCount] = await Promise.all([
      db.knex("bills as b")
        .where({ "b.sponsor_bioguide_id": upperId })
        .select(
            "b.billid", db.knex.raw("b.billnumber::text AS billnumber"), "b.billtype", db.knex.raw("b.congress::text AS congress"),
            "b.shorttitle", "b.officialtitle", "b.introducedat", "b.statusat", "b.bill_status",
            "b.summary_text", "b.policy_area", "b.latest_action_date",
            db.knex.raw(
              "(SELECT COUNT(*)::int FROM bill_cosponsors cos WHERE cos.billtype = b.billtype AND cos.billnumber = b.billnumber AND cos.congress = b.congress) AS cosponsor_count"
            )
        )
        .orderByRaw("b.latest_action_date DESC NULLS LAST")
        .limit(20),
        
      db.knex("vote_members")
        .join("votes", "vote_members.voteid", "votes.voteid")
        .where("vote_members.bioguide_id", upperId)
        .select(
            "votes.voteid", db.knex.raw("votes.congress::text AS congress"), "votes.chamber",
            "votes.question", "votes.result", "votes.votedate",
            "votes.votetype", db.knex.raw("votes.votenumber::text AS votenumber"), "vote_members.position"
        )
        .orderBy("votes.votedate", "desc")
        .limit(50),
        
      db.knex("bills")
        .where({ sponsor_bioguide_id: upperId })
        .count("* as total")
        .first(),
        
      db.knex("bill_cosponsors")
        .where({ bioguide_id: upperId })
        .count("* as total")
        .first()
    ]);

    return {
        bioguide_id: upperId,
        name: profile.name,
        party: profile.party,
        state: profile.state,
        counts: {
            sponsored: parseInt(sponsoredCount?.total || 0),
            cosponsored: parseInt(cosponsoredCount?.total || 0),
        },
        sponsoredBills,
        recentVotes
    };
  });
};
