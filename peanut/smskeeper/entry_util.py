import re
import logging

from smskeeper import msg_util, user_util

from smskeeper.models import Entry
logger = logging.getLogger(__name__)

from fuzzywuzzy import fuzz


def fuzzyMatchEntries(user, msg, keeperNumber, justSentEntries):
	cleanedCommand = msg_util.cleanCommand(msg)
	phrases = cleanedCommand.split("and")
	entries = set()

	if len(phrases) > 1:
		# append the original if it got split up since the actual entry might include "and"
		# e.g. "call bob and sue"
		phrases.append(cleanedCommand)

	for phrase in phrases:
		# This could be put into a regex
		phrase = phrase.strip()
		if phrase == "" or re.match("all$|everything$|every thing$|both$", phrase, re.I):
			if justSentEntries:
				entries = justSentEntries
			else:
				# Do we want to include all here?
				entries = user_util.pendingTodoEntries(user, includeAll=False)
			logging.info("User %s: Fuzzy matching multiple entries %s since the phrase was short" % (user.id, [x.id for x in entries]))
			break
		else:
			bestMatch, score = getBestEntryMatch(user, phrase)
			if score >= 60:
				logger.info("User %s: Fuzzy matching entry '%s' (%s) due to score of %s" % (user.id, bestMatch.text, bestMatch.id, score))
				entries.add(bestMatch)

	if len(entries) == 0:
		logger.info("User %s: Couldn't find a good fuzzy match." % (user.id))
	return list(entries)


def getBestEntryMatch(user, msg, entries=None):
	if not entries:
		entries = Entry.objects.filter(creator=user, label="#reminders", hidden=False)

	logger.debug("User %s: Going to try to find the best match to '%s'" % (user.id, msg))
	entries = sorted(entries, key=lambda x: x.added)

	bestMatch = None
	bestScore = 0

	for entry in entries:
		score = fuzz.token_set_ratio(entry.text, msg)
		if score > bestScore:
			logger.debug("User %s: Message %s got score %s, higher than best of %s. New Best" % (user.id, entry.text, score, bestScore))
			bestMatch = entry
			bestScore = score
		else:
			logger.debug("User %s: Message %s got score %s, lower than best of %s" % (user.id, entry.text, score, bestScore))

	if bestMatch:
		logger.debug("User %s: Decided on best match of %s to '%s' with score %s" % (user.id, bestMatch.text, msg, bestScore))
	else:
		logger.debug("User %s: Decided on no best to '%s'" % (user.id, msg))
	return (bestMatch, bestScore)
