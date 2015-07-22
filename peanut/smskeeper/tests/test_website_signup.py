from mock import patch
from django.test.client import RequestFactory

from smskeeper import msg_util, cliMsg, keeper_constants
from smskeeper import views
from smskeeper.models import User
from smskeeper import keeper_constants

import test_base
import json


class SMSKeeperWebsiteSignupCase(test_base.SMSKeeperBaseCase):

	# This now should be product id 1
	def test_signup_product_id_0(self):
		request = self.createRequest('+16505759014', exp='reminders1')
		response = views.signup_from_website(request) #httpresponse
		self.assertIn('"result": true', response.content)

		# fetch the user to verify that product_id is 0
		users = User.objects.all()
		self.assertEquals(1, len(users))

		self.assertEquals(users[0].product_id, keeper_constants.TODO_PRODUCT_ID)
		self.assertEquals(users[0].state, keeper_constants.STATE_TUTORIAL_TODO)


	def test_signup_product_id_1(self):
		request = self.createRequest('+16505759014')
		response = views.signup_from_website(request) #httpresponse
		self.assertIn('"result": true', response.content)

		# fetch the user to verify that product_id is 1
		users = User.objects.all()
		self.assertEquals(1, len(users))
		self.assertEquals(users[0].product_id, keeper_constants.TODO_PRODUCT_ID)
		self.assertEquals(users[0].state, keeper_constants.STATE_TUTORIAL_TODO)


	def createRequest(self, phoneNumber, source='default', exp='',paid='0'):
		rf = RequestFactory()
		params = "?phone_number=" + str(phoneNumber) + "&source=" + str(source) + '&exp=' + str(exp) + '&paid=' + str(paid)
		getRequest = rf.get('/smskeeper/signup_from_website'+ params)
		return getRequest



