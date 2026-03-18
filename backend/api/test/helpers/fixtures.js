'use strict';

// ---------------------------------------------------------------------------
// Reusable test data for route integration tests
// ---------------------------------------------------------------------------

const SAMPLE_BILL_LIST_ITEM = {
  billid: 1001,
  shorttitle: 'Test Infrastructure Act',
  officialtitle: 'A bill to invest in test infrastructure',
  introducedat: '2025-01-15',
  summary_text: 'Provides funding for automated testing infrastructure.',
  billtype: 'hr',
  congress: '119',
  billnumber: '42',
  sponsor_name: 'Jane Doe',
  sponsor_party: 'D',
  sponsor_state: 'CA',
  sponsor_bioguide_id: 'D000001',
  bill_status: 'passed',
  statusat: '2025-03-01',
  policy_area: 'Science, Technology, Communications',
  latest_action_date: '2025-03-01',
  origin_chamber: 'House',
  cosponsor_count: 12,
};

const SAMPLE_BILL_DETAIL = {
  billid: 1001,
  billnumber: '42',
  billtype: 'hr',
  congress: '119',
  shorttitle: 'Test Infrastructure Act',
  officialtitle: 'A bill to invest in test infrastructure',
  introducedat: '2025-01-15',
  statusat: '2025-03-01',
  bill_status: 'passed',
  summary_text: 'Provides funding for automated testing infrastructure.',
  summary_date: '2025-01-20',
  sponsor_name: 'Jane Doe',
  sponsor_party: 'D',
  sponsor_state: 'CA',
  sponsor_bioguide_id: 'D000001',
  origin_chamber: 'House',
  policy_area: 'Science, Technology, Communications',
  update_date: '2025-03-01',
  latest_action_date: '2025-03-01',
};

const SAMPLE_ACTION = {
  acted_at: '2025-01-15',
  action_text: 'Introduced in House',
  action_type: 'IntroReferral',
  action_code: 'Intro-H',
};

const SAMPLE_COSPONSOR = {
  bioguide_id: 'S000001',
  full_name: 'John Smith',
  state: 'NY',
  party: 'R',
  sponsorship_date: '2025-01-16',
  is_original_cosponsor: true,
};

const SAMPLE_BILL_VOTE = {
  voteid: 'h42-119.2025',
  congress: '119',
  chamber: 'house',
  question: 'On Passage',
  result: 'Passed',
  votedate: '2025-02-15',
  votetype: 'YEA-AND-NAY',
};

const SAMPLE_VOTE_WITH_COUNTS = {
  congress: '119',
  votenumber: 1,
  votedate: '2025-02-15',
  question: 'On Passage: H.R. 42',
  votesession: '2025',
  result: 'Passed',
  chamber: 'house',
  votetype: 'YEA-AND-NAY',
  voteid: 'h1-119.2025',
  source_url: 'https://clerk.house.gov/Votes/20251',
  yea: 220,
  nay: 210,
  present: 2,
  notvoting: 3,
};

const SAMPLE_USER = {
  email: 'testuser@example.com',
  given_name: 'Test',
  family_name: 'User',
};

module.exports = {
  SAMPLE_BILL_LIST_ITEM,
  SAMPLE_BILL_DETAIL,
  SAMPLE_ACTION,
  SAMPLE_COSPONSOR,
  SAMPLE_BILL_VOTE,
  SAMPLE_VOTE_WITH_COUNTS,
  SAMPLE_USER,
};
