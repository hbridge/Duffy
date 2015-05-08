#!/usr/bin/env python
#coding=utf-8

import sys
import argparse

from smskeeper import processing_util
from peanut.settings import constants

"""
	Helper method for command line interface input.  Use by:
	python
	>> from smskeeper import views
	>> views.cliMsg("+16508158274", "blah #test")
"""
def msg(phoneNumber, msg, mediaURL=None, mediaType=None, cli=False):
	numMedia = 0
	jsonDict = {
		"Body": msg,
	}

	if mediaURL is not None:
		numMedia = 1
		jsonDict["MediaUrl0"] = mediaURL
		if mediaType is not None:
			jsonDict["MediaContentType0"] = mediaType
		jsonDict["NumMedia"] = 1
	else:
		jsonDict["NumMedia"] = 0

	keeperNumber = constants.SMSKEEPER_TEST_NUM
	if cli:
		keeperNumber = constants.SMSKEEPER_CLI_NUM

	processing_util.processMessage(phoneNumber, msg, jsonDict, keeperNumber)


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
