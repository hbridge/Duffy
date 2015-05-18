import time

from smskeeper import sms_util, msg_util
from smskeeper import actions

from smskeeper.models import Entry


def sendContactCard(user, keeperNumber):
		cardURL = "https://s3.amazonaws.com/smskeeper/Keeper.vcf"
		sms_util.sendMsg(user, '', cardURL, keeperNumber)


def process(user, msg, requestDict, keeperNumber):
	stateData = None
	if user.state_data:
		stateData = int(user.state_data)

	if not stateData:
		nameFromPhrase = msg_util.nameInSetName(msg)
		if nameFromPhrase:
			user.name = nameFromPhrase
		else:
			user.name = msg.strip()
		user.save()
		sms_util.sendMsg(user, "Great, nice to meet you %s!" % user.name, None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Let me show you the basics. I remember anything you send me with a hashtag.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Let's make your shopping list. Just type 'pasta #shopping'. Try it now.", None, keeperNumber)
		user.state_data = 1
	elif stateData == 1:
		if not msg_util.hasLabel(msg):
			# They didn't send in something with a label.
			sms_util.sendMsg(user, "Actually, let's create a list first. Try 'pasta #shopping'.", None, keeperNumber)
		else:
			# They sent in something with a label, have them add to it
			actions.add(user, msg, requestDict, keeperNumber, False, True)
			sms_util.sendMsg(user, "Now let's add other items to your list. Don't forget to add your hashtag again. '%s'" % msg_util.getLabel(msg), None, keeperNumber)
			user.state_data = stateData + 1
	elif stateData == 2:
		# They should be sending in a second add command to an existing label
		if not msg_util.hasLabel(msg) or msg_util.isLabel(msg):
			existingLabel = Entry.fetchFirstLabel(user)
			if not existingLabel:
				sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
				return True
			sms_util.sendMsg(user, "Actually, let's add to the first list. Try 'visit atm %s'." % existingLabel, None, keeperNumber)
		else:
			actions.add(user, msg, requestDict, keeperNumber, False, True)
			sms_util.sendMsg(user, "Got it. You can send items to this hashtag anytime (including photos). To see your items, send just the hashtag '%s' to me. Give it a shot." % msg_util.getLabel(msg), None, keeperNumber)
			user.state_data = stateData + 1
	elif stateData == 3:
		# The should be sending in just a label
		existingLabel = Entry.fetchFirstLabel(user)
		if not existingLabel:
			sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
			return

		if not msg_util.isLabel(msg):
			sms_util.sendMsg(user, "Actually, let's view your list. Try '%s'." % existingLabel, None, keeperNumber)
			return True

		if msg not in Entry.fetchAllLabels(user):
			sms_util.sendMsg(user, "Actually, let's view the list you already created. Try '%s'." % existingLabel, None, keeperNumber)
			return True
		else:
			actions.fetch(user, msg, keeperNumber)
			sms_util.sendMsg(user, "You got it. You can also send 'huh?' anytime to get help.", None, keeperNumber)
			time.sleep(1)
			sms_util.sendMsg(user, "And here are some ideas to start you off: movies to watch, restaurants to try, books to read, or even a food journal. Try creating your own list.", None, keeperNumber)

			user.setTutorialComplete()

	user.save()
	return True
