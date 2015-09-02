import json
import datetime
import os
import sys
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.http import HttpResponse
from smskeeper.models import User
from smskeeper.models import Entry
from common import date_util

logger = logging.getLogger(__name__)

from icalendar import Calendar
from icalendar import Event
from icalendar import vCalAddress
from icalendar import vText


def icsFeed(request, key):
	key = ["K" + key, "P" + key]
	try:
		user = User.objects.get(key__in=key)
		icsText = icsFeedForUser(user)
		return HttpResponse(icsText, content_type="text/calendar", status=200)
	except User.DoesNotExist:
		return HttpResponse(json.dumps({"Errors": "User not found"}), content_type="text/json", status=400)


def icsFeedForUser(user):
	cal = Calendar()
	cal.add('prodid', "-//%s's Keeper Calendar//getkeeper.com//" % user.name)
	cal.add('version', '2.0')

	weekAgo = date_util.now() - datetime.timedelta(days=7)
	entries = Entry.fetchEntries(user, label="#reminders", hidden=None, orderByString="-remind_timestamp")
	entries = entries.exclude(remind_timestamp__lt=weekAgo)
	for entry in entries:
		event = Event()
		event.add('summary', entry.text)
		event.add('dtstart', entry.remind_timestamp)
		event.add('dtend', entry.remind_timestamp + datetime.timedelta(hours=1))
		event.add('dtstamp', entry.added)

		# people
		organizer = vCalAddress('MAILTO:support@getkeeper.com')
		organizer.params['cn'] = vText('Keeper')
		organizer.params['role'] = vText('CHAIR')
		event['organizer'] = organizer
		event['uid'] = entry.id
		event.add('priority', 5)

		attendee = vCalAddress('SMS:' + user.phone_number)
		attendee.params['cn'] = vText(user.name)
		attendee.params['ROLE'] = vText('REQ-PARTICIPANT')
		event.add('attendee', attendee, encode=0)

		cal.add_component(event)

	return cal.to_ical()
