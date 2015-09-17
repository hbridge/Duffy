import logging

from smskeeper import msg_util, niceties

logger = logging.getLogger(__name__)

from fuzzywuzzy import fuzz


def isWildcardPhrase(msg):
	interestingWords = msg_util.getInterestingWords(msg)
	# Is it a "done with all". Determine by looking if there's any interesting words
	if (len(interestingWords) == 0 or niceties.getNicety(msg)):
		return True
	return False


def fuzzyMatchEntries(user, cleanedCommand, minScore=60):
	phrases = cleanedCommand.split(" and ")
	entries = set()

	if len(phrases) > 1:
		# append the original if it got split up since the actual entry might include "and"
		# e.g. "call bob and sue"
		phrases.append(cleanedCommand)

		for phrase in phrases:
			phrase = phrase.strip()
			interestingPhrase = ' '.join(msg_util.getInterestingWords(phrase))

			bestMatch, score = getBestEntryMatch(user, phrase)
			if score >= minScore:
				logger.debug("User %s: Fuzzy matching entry '%s' (%s) due to score of %s (min %s)" % (user.id, bestMatch.text, bestMatch.id, score, minScore))
				entries.add(bestMatch)
	elif len(phrases) == 1:
		interestingPhrase = ' '.join(msg_util.getInterestingWords(cleanedCommand))

		bestMatch, score = getBestEntryMatch(user, interestingPhrase)
		if score >= minScore:
			logger.debug("User %s: Fuzzy matching entry '%s' (%s) with '%s' due to score of %s (min %s)" % (user.id, bestMatch.text, bestMatch.id, interestingPhrase, score, minScore))
			entries.add(bestMatch)
		else:
			logger.debug("User %s: Didn't find match, using interesting words: '%s'" % (user.id, interestingPhrase))

	if len(entries) == 0:
		logger.debug("User %s: Couldn't find a good fuzzy match." % (user.id))
	return list(entries)


def getBestEntryMatch(user, msg, entries=None):
	if not entries:
		entries = user.getActiveEntries()

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
