from django.conf import settings
import logging
logger = logging.getLogger(__name__)

from zdesk import Zendesk
from zdesk import get_id_from_url

if hasattr(settings, "ZENDESK_URL"):
	zendesk = Zendesk(settings.ZENDESK_URL, 'henry@duffytech.co', settings.ZENDESK_TOKEN, True)
else:
	zendesk = None

from smskeeper.models import Message


def createUnknownCommandTicket(user, msg):
	if zendesk is None:
		return
	zendeskId = getOrCreateZendeskUserId(user)

	recentMessages = Message.objects.all().order_by("-id")[:10]
	descriptionText = "Unknown message: '%s'\n" % msg
	descriptionText += "User history: http://prod.strand.duffyapp.com/smskeeper/history?user_id=%d\n" % user.id
	descriptionText += "\nRecent Message History:\n"
	for recentMessage in reversed(recentMessages):
		descriptionText += user.name if recentMessage.incoming else "Keeper"
		descriptionText += ": "
		descriptionText += recentMessage.getBody()
		descriptionText += "\n"
	descriptionText += "%s: %s" % (user.name, msg)

	new_ticket = {
		'ticket': {
			'requester_id': zendeskId,
			'requester_name': user.name,
			'subject': 'Unknown: "%s"' % msg,
			'description': descriptionText,
			'set_tags': 'unknown',
		}
	}

	# Create the ticket and get its URL
	try:
		result = zendesk.ticket_create(data=new_ticket)
		logger.info("Created zendesk ticket: %s", result)
	except Exception as e:
		logger.error("Couldn't create Zendesk ticket for user %d: %s", user.id, e)


def getOrCreateZendeskUserId(user):
	if zendesk is None:
		return 0
	if user.zendesk_id:
		return user.zendesk_id

	new_user = {
		'user': {
			'name': user.name,
			'phone': user.phone_number,
			'external_id': user.id,
		}
	}
	try:
		result = zendesk.user_create(data=new_user)
		zendesk_id = get_id_from_url(result)
	except Exception as e:
		logger.error("Couldn't create zendesk user for uid: %d: %s", user.id, e)

	user.zendesk_id = zendesk_id
	user.save()
	return zendesk_id
