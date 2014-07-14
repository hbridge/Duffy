import unittest
import urllib2
import json
import sys

class BlackBoxUrlsTests(unittest.TestCase):
	BASEURL = "strand.prod.duffyapp.com"
	USER_ID = 12

	def testNeighbor(self):
		url = 'http://%s/strand/api/neighbors?user_id=%s' % (self.BASEURL, self.USER_ID)
		print "Testing: %s" % (url)
		response = urllib2.urlopen(url)
		result = json.loads(response.read())

		self.assertTrue("objects" in result)

if __name__ == '__main__':
	if len(sys.argv) == 3:
		# Backwards to forwards
		BlackBoxUrlsTests.USER_ID = sys.argv.pop()
		BlackBoxUrlsTests.BASEURL = sys.argv.pop()
	else:
		sys.exit("You need to pass in a base url")

	unittest.main()
