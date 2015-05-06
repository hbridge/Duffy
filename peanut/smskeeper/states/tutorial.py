import time
import random
import datetime
import pytz

from smskeeper import sms_util, msg_util, helper_util
from smskeeper import keeper_constants
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
		user.name = msg
		user.save()
		sms_util.sendMsg(user, "Great, nice to meet you %s!" % user.name, None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Let me show you the basics. Send me an item you want to buy and add a hashtag. Like 'bread #shopping'", None, keeperNumber)
		user.state_data = 1
	elif stateData == 1:
		if not msg_util.hasLabel(msg):
			# They didn't send in something with a label.
			sms_util.sendMsg(user, "Actually, let's create a list first. Try 'bread #shopping'.", None, keeperNumber)
		else:
			# They sent in something with a label, have them add to it
			actions.add(user, msg, requestDict, keeperNumber, False)
			sms_util.sendMsg(user, "Now send me another item for the same list. Don't forget to add the same hashtag '%s'" % msg_util.getLabel(msg), None, keeperNumber)
			user.state_data = stateData + 1
	elif stateData == 2:
		# They should be sending in a second add command to an existing label
		if not msg_util.hasLabel(msg) or msg_util.isLabel(msg):
			existingLabel = Entry.fetchFirstLabel(user)
			if not existingLabel:
				sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
				return
			sms_util.sendMsg(user, "Actually, let's add to the first list. Try 'foobar %s'." % existingLabel, None, keeperNumber)
		else:
			actions.add(user, msg, requestDict, keeperNumber, False)
			sms_util.sendMsg(user, "You can send items to this hashtag anytime (including photos). To see your items, send just the hashtag '%s' to me. Give it a shot." % msg_util.getLabel(msg), None, keeperNumber)
			user.state_data = stateData + 1
	elif stateData == 3:
		# The should be sending in just a label
		existingLabel = Entry.fetchFirstLabel(user)
		if not existingLabel:
			sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
			return

		if not msg_util.isLabel(msg):
			sms_util.sendMsg(user, "Actually, let's view your list. Try '%s'." % existingLabel, None, keeperNumber)
			return

		if not msg in Entry.fetchAllLabels(user):
			sms_util.sendMsg(user, "Actually, let's view the list you already created. Try '%s'." % existingLabel, None, keeperNumber)
			return
		else:
			actions.fetch(user, msg, keeperNumber)
			sms_util.sendMsg(user, "That's all you need to know for now. Send 'huh?' anytime to get help.", None, keeperNumber)
			time.sleep(1)
			sms_util.sendMsg(user, "Btw, here's an easy way to add me to your contacts.", None, keeperNumber)
			time.sleep(1)
			sendContactCard(user, keeperNumber)
			user.completed_tutorial = True

			user.setState(keeper_constants.STATE_NORMAL)

	user.save()