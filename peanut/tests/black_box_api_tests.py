import unittest
import urllib
import urllib2
import json
import sys
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
	
import strand.forms as forms



class BlackBoxUrlsTests(unittest.TestCase):
	defaultParams = dict()
	BASEURL = "strand.prod.duffyapp.com"
	defaultParams['user_id'] = 12
	defaultParams['start_date_time'] = '2014-07-09 18:45:57'
	defaultParams['lat'] = 40.0
	defaultParams['lon'] = -70
	defaultParams['device_token'] = "LKDAFJLDSKFJSLDFJ"
	defaultParams['phone_number'] = "+17815555559"
	defaultParams['sms_access_code'] = "2345"
	defaultParams['display_name'] = "Derek"
	defaultParams['phone_id'] = "ldkfjaldkjf"

	statsLines = list()
	urlLines = list()

	@classmethod
	def tearDownClass(cls):
		print ""
		print ""
		print "Urls Tested:"
		for line in cls.urlLines:
			print line

		print ""
		print "Stats:"
		for line in cls.statsLines:
			print line

	def getResult(self, name, form):
		params = dict()
		formVarNames = {key:value for key, value in form.__dict__['base_fields'].items() if not key.startswith('__') and not callable(key)}
		for varName in formVarNames:
			if varName in self.defaultParams:
				params[varName] = self.defaultParams[varName]

		queryString = urllib.urlencode(params)
		url = "http://%s/strand/api/v1/%s?%s" % (self.BASEURL, name, queryString)
		self.urlLines.append("Testing: %s" % (url))
		response = urllib2.urlopen(url)
		result = json.loads(response.read())
		return result
		
	def testSummary(self):
		url = 'http://%s/viz/summary' % (self.BASEURL)
		self.urlLines.append('Testing: %s' % (url))
		response = urllib2.urlopen(url)
		result = str(response.read())
		statsStart = result.find('Total time')
		statsEnd = result[statsStart:].find('<')

		self.statsLines.append("/viz/summary stats: %s" % (result[statsStart:][:statsEnd])) 

		self.assertTrue("Clustered" in result)
		self.assertTrue("Fulls" in result)

	def testNeighbor(self):
		result = self.getResult('neighbors', forms.OnlyUserIdForm)

		self.statsLines.append("/strand/api/neighbors stats: %s" % (result['stats']))
		self.assertTrue("objects" in result)
	
	def testGetJoinableStrands(self):
		result = self.getResult('get_joinable_strands', forms.GetJoinableStrandsForm)
		self.assertTrue("objects" in result)

	def testGetNewPhotos(self):
		result = self.getResult('get_new_photos', forms.GetNewPhotosForm)
		self.assertTrue("objects" in result)

	def testRegisterApnsToken(self):
		result = self.getResult('register_apns_token', forms.RegisterAPNSTokenForm)
		self.assertTrue("result" in result)

	def testUpdateUserLocation(self):
		result = self.getResult('update_user_location', forms.UpdateUserLocationForm)
		self.assertTrue("result" in result)

	def testGetNearbyFriendsMessage(self):
		result = self.getResult('get_nearby_friends_message', forms.GetFriendsNearbyMessageForm)
		self.assertTrue("message" in result)

	def testSendSmsCode(self):
		result = self.getResult('send_sms_code', forms.SendSmsCodeForm)
		self.assertTrue("debug" in result)

	def testAuthPhone(self):
		result = self.getResult('auth_phone', forms.AuthPhoneForm)
		self.assertTrue("user" in result)

	def testGetInviteMessage(self):
		result = self.getResult('get_invite_message', forms.OnlyUserIdForm)
		self.assertTrue("invite_message" in result)		

if __name__ == '__main__':
	if len(sys.argv) == 3:
		# Backwards to forwards
		BlackBoxUrlsTests.defaultParams['user_id'] = sys.argv.pop()
		BlackBoxUrlsTests.BASEURL = sys.argv.pop()
	else:
		sys.exit("You need to pass in a base url")

	unittest.main()

