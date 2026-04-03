import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tasks"))

import votes


class Votes(unittest.TestCase):

    def test_house_vote_number_from_https_href_with_rollnumber_first(self):
        href = "https://clerk.house.gov/cgi-bin/vote.asp?rollnumber=108&year=2026"
        self.assertEqual(votes.house_vote_number_from_href(href, "2026"), "108")

    def test_house_vote_number_from_http_href_with_year_first(self):
        href = "http://clerk.house.gov/cgi-bin/vote.asp?year=2026&rollnumber=91"
        self.assertEqual(votes.house_vote_number_from_href(href, "2026"), "91")

    def test_house_vote_number_rejects_other_sessions(self):
        href = "https://clerk.house.gov/cgi-bin/vote.asp?rollnumber=108&year=2025"
        self.assertIsNone(votes.house_vote_number_from_href(href, "2026"))

    def test_house_group_id_from_relative_href(self):
        self.assertEqual(votes.house_group_id_from_href("ROLL_100.asp"), "100")
