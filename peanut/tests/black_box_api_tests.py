import unittest
import urllib
import urllib2
import json
import sys
import os
import requests
from werkzeug.datastructures import MultiDict


parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants
from common.models import User
	
import strand.forms as forms


"""
Top level class for all tests in Swap. Contains helper functions
"""
class SwapTests(unittest.TestCase):


	BASEURL = "strand.prod.duffyapp.com"
	
	### Predetermined inputs
	defaultParams = dict()
	defaultParams['phone_number'] = ['+16205555551', '+16205555552', '+16205555553']
	defaultParams['sms_access_code'] = ["2345", "2345", "2345"]
	defaultParams['display_name'] = ['Unitester1', 'Unitester2', 'Unitester3']
	defaultParams['phone_id'] = ["tester1", "tester2", "tester3"]
	defaultParams['device_token'] = ['dtoken1']
	defaultParams['user_id'] = [12]
	# defaultParams['start_date_time'] = '2014-07-09 18:45:57'
	# defaultParams['lat'] = 40.0
	# defaultParams['lon'] = -70

	urlLines = list()
	userList = list()

	# Matches up a form's required params to the list in default params
	def formToParams(self, name, form, cursor):
		params = dict()
		formVarNames = {key:value for key, value in form.__dict__['base_fields'].items() if not key.startswith('__') and not callable(key)}
		for varName in formVarNames:
			if varName in self.defaultParams:
				params[varName] = self.defaultParams[varName][cursor]

		return self.getResultFromURL(name, params)

	# gets json results back from a url
	def getResultFromURL(self, name, params):
		queryString = urllib.urlencode(params)
		url = "http://%s/strand/api/v1/%s?%s" % (self.BASEURL, name, queryString)
		self.urlLines.append("Testing: %s" % (url))
		response = urllib2.urlopen(url)
		result = json.loads(response.read())
		return result

	# Returns set of random users from the database
	def getRandomUsers(self, count=3):
		return [user.id for user in User.objects.filter(product_id=2).order_by('?')[:count]]	

	def getContactsData(self):
		contacts = list()
		for i, item in enumerate(self.userList):
			entry = dict()
			entry['user'] = item
			entry['name'] = self.defaultParams['display_name'][i]
			entry['phone_number'] = self.defaultParams['phone_number'][i]
			contacts.append(entry)
		return contacts
	
	### Functions to access specific pages
	def getStrandInbox(self, userId):
		return self.getResultFromURL('strand_inbox', {'user_id':userId})

	def getSwaps(self, userId):
		return self.getResultFromURL('swaps', {'user_id':userId})

	def getUnsharedStrands(self, userId):
		return self.getResultFromURL('unshared_strands', {'user_id':userId})

	def steps(self):
		for name in sorted(dir(self)):
			if name.startswith("step"):
				yield name, getattr(self, name) 

	@classmethod
	def tearDownClass(self):

		# delete the three new user accounts and all associated data will go away
		userList = User.objects.filter(id__in=self.userList)
		if len(userList) > 0:
			userList.delete()

		# display results
		print ""
		print ""
		print "Urls Tested:"
		for line in self.urlLines:
			print line

	###########################################################################
	############################### TESTS #####################################
	###########################################################################


	### 1. Tests for existing users ###

	# Loads Inbox page
	def testStrandInbox(self):
		userList = self.getRandomUsers()
		for userId in userList:
			result = self.getStrandInbox(userId)
			self.assertTrue("objects" in result)

	# Load Swaps tab
	def testSwapsCall(self):
		userList = self.getRandomUsers()		
		for userId in userList:
			result = self.getSwaps(userId)
			self.assertTrue("objects" in result)

	# Load private strands
	def testPrivateStrandsCall(self):
		userList = self.getRandomUsers()		
		for userId in userList:
			result = self.getUnsharedStrands(userId)
			self.assertTrue("objects" in result)




	### 2. Tests for one-off URLS ###
	
	# Create Account
	def step1AuthPhone(self):
		for i, entry in enumerate(self.defaultParams['phone_number']):
			result = self.formToParams('auth_phone', forms.AuthPhoneForm, i)
			self.assertTrue("user" in result)
			self.userList.append(result['user']['id'])

	# Make them friends
	def step2UploadContacts(self):
		for i, entry in enumerate(self.defaultParams['phone_number']):
			url = 'http://' + self.BASEURL + '/strand/api/v1/contacts/'
			contactsData = self.getContactsData()
			headers = {'Content-Type': "application/json"}
			payload = {'contacts': contactsData}
			response = requests.post(url, data=json.dumps(payload), headers=headers)
			result = json.loads(response.text)
			self.assertTrue("contacts" in result)
			self.assertTrue("updated" in result['contacts'][0])

	# Upload some photos
	def step3UploadPhotos(self):
		# TODO
		pass

	def step4LoadPrivateStrands(self):
		for userId in self.userList:
			result = self.getUnsharedStrands(userId)
			self.assertTrue("objects" in result)

	# Load suggestions and swaps
	def step5LoadSwaps(self):
		for userId in self.userList:
			result = self.getSwaps(userId)
			self.assertTrue("objects" in result)

	# Load inbox
	def step6LoadInbox(self):
		#TODO after step 3 is implemented (no way to swap photos until then)
		pass

	def testNewUserFlow(self):
		for name, step in self.steps():
			try:
				step()
			except Exception as e:
				self.fail("{} failed ({}: {})".format(step, type(e), e))




	### 3. Tests for one-off URLS using Unittest account###

	# Send SMS Code
	def testSendSmsCode(self):
		result = self.formToParams('send_sms_code', forms.SendSmsCodeForm, 0)
		self.assertTrue("debug" in result)

	# Register apns token
	def testRegisterApnsToken(self):
		result = self.formToParams('register_apns_token', forms.RegisterAPNSTokenForm, 0)
		self.assertTrue("result" in result)




	### 4. Tests for internal pages ###

	# Summary page
	def testSummary(self):
		url = 'http://%s/viz/summary' % (self.BASEURL)
		self.urlLines.append('Testing: %s' % (url))
		response = urllib2.urlopen(url)
		result = str(response.read())

		self.assertTrue("last-build" in result)
		self.assertTrue("Last Upload" in result)


if __name__ == '__main__':
	if len(sys.argv) == 3:
		# Backwards to forwards
		SwapTests.defaultParams['user_id'] = [sys.argv.pop()]
		SwapTests.BASEURL = sys.argv.pop()
	else:
		sys.exit("You need to pass in a base url and a unittest account")

	unittest.main()
	#ExistingUsersAccountsSuite = unittest.TestLoader().loadTestsFromTestCase(ExistingUsersAccountsTests)
	#OneOffMethodsSuite = unittest.TestLoader().loadTestsFromTestCase(OneOffMethodsTests)
	#unittest.TextTestRunner(verbosity=2).run(ExistingUsersAccountsSuite)	
	#unittest.TextTestRunner(verbosity=2).run(OneOffMethodsSuite)
