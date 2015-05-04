#!/usr/bin/env python
#coding=utf-8

import sys
import argparse


def main():
	parser = argparse.ArgumentParser(description='Simulate a text message')
	parser.add_argument('text', help="text to send to server")
	parser.add_argument('-p', '--phone', dest='phone', required=True, help="The user phone number to simulate")
	parser.add_argument('-m', '--mediaUrl', dest='media_url', required=False, help="A media url to attach to the message")
	parser.add_argument('-t', '--mediaType', dest='media_type', required=False, help="A mime type for the media e.g. image/jpeg")
	args = parser.parse_args()
	print "%s: '%s'" % (args.phone, args.text)

	import views
	views.cliMsg(args.phone, args.text, args.media_url, args.media_type)

if __name__ == "__main__":
	sys.exit(main())
