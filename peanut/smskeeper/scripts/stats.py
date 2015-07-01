#!/usr/bin/python
import sys
import os
import operator
import json

import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Q

from smskeeper.models import User, Entry
from smskeeper import keeper_constants, msg_util

logger = logging.getLogger(__name__)


def main(argv):
	print "Starting..."
	"""
	ignoreList = ["your", "about", "take", "with", "that", "have"]

	entries = Entry.objects.all()

	wordDict = dict()
	for entry in entries:
		if not entry.text:
			continue

		for word in entry.text.split(' '):
			if len(word) <= 2 or word in ignoreList:
				continue
			word = word.lower()
			if word not in wordDict:
				wordDict[word] = 0
			wordDict[word] += 1

	sortedWordDict = sorted(wordDict.items(), key=operator.itemgetter(1), reverse=True)

	for x in range(0, 40):
		print sortedWordDict[x]

	"""

	entries = Entry.objects.all()

	wordDict = dict()
	for entry in entries:
		if not entry.text or not entry.orig_text:
			continue

		try:
			first = json.loads(entry.orig_text)[0]
		except:
			first = entry.orig_text

		handle = msg_util.getReminderHandle(first)

		if handle not in wordDict:
			wordDict[handle] = 0
		wordDict[handle] += 1

	sortedWordDict = sorted(wordDict.items(), key=operator.itemgetter(1), reverse=True)

	for x in range(0, 40):
		print sortedWordDict[x]

	print "Donezo!"

if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])
