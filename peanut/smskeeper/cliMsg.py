#!/usr/bin/env python
#coding=utf-8

import sys, os
import argparse
import random
import time

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants
from smskeeper import processing_util


"""
	Helper method for command line interface input.  Use by:
	python
	>> from smskeeper import views
	>> views.cliMsg("+16508158274", "blah #test")

	NOTE:  Make sure all values here are strings instead of ints so it accuratly reflects what comes in on the web
"""

def msgTelegram(telegramId, msg, cli=False):
	jsonDict = {
		'update_id': random.randint(1, 10000000),
		'message': {
			'from': {
				'first_name': u'Test',
				'last_name': u'User',
				'id': int(telegramId)
			},
			'chat': {
				'first_name': u'Test',
				'last_name': u'User',
				'id': int(telegramId),
				'type': u'private'
			},
			'text': msg,
			'date': int(time.time()),
			'message_id': 0,
		}
	}

	userNumber = telegramId + "@telegram.me"
	keeperNumber = "Henry_bot@telegram.me"

	processing_util.processMessage(userNumber, msg, jsonDict, keeperNumber, False)


def msgTwilio(phoneNumber, msg, mediaURL=None, mediaType=None, cli=False, keeperNumber=None):
	numMedia = 0
	jsonDict = {
		"Body": msg,
	}

	if mediaURL is not None:
		numMedia = "1"
		jsonDict["MediaUrl0"] = mediaURL
		if mediaType is not None:
			jsonDict["MediaContentType0"] = mediaType
		jsonDict["NumMedia"] = "1"
	else:
		jsonDict["NumMedia"] = "0"

	if not keeperNumber:
		keeperNumber = constants.SMSKEEPER_TEST_NUM

	if cli:
		keeperNumber = constants.SMSKEEPER_CLI_NUM

	processing_util.processMessage(phoneNumber, msg, jsonDict, keeperNumber, False)


def msg(phoneNumber, msg, mediaURL=None, mediaType=None, cli=False, keeperNumber=None):
	if "@telegram" in phoneNumber:
		msgTelegram(phoneNumber.split("@")[0], msg, cli)
	else:
		msgTwilio(phoneNumber, msg, mediaURL, mediaType, cli, keeperNumber)


def main():
	parser = argparse.ArgumentParser(description='Simulate a text message')
	parser.add_argument('text', help="text to send to server")
	parser.add_argument('-p', '--phone', dest='phone', required=True, help="The user phone number to simulate")
	parser.add_argument('-m', '--mediaUrl', dest='media_url', required=False, help="A media url to attach to the message")
	parser.add_argument('-t', '--mediaType', dest='media_type', required=False, help="A mime type for the media e.g. image/jpeg")
	args = parser.parse_args()
	print "%s: '%s'" % (args.phone, args.text)

	msg(args.phone, args.text, args.media_url, args.media_type, True)

if __name__ == "__main__":
	sys.exit(main())
