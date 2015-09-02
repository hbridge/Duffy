import json
import datetime
import pytz
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
from icalendar import vDatetime



def icsFeed(request, key):
	keys = ["K" + key, "P" + key]
	try:
		user = User.objects.get(key__in=keys)
		icsText = icsFeedForUser(user)
		return HttpResponse(icsText, content_type="text/calendar", status=200)
	except User.DoesNotExist:
		return HttpResponse(json.dumps({"Errors": "User not found"}), content_type="text/json", status=400)


def icsFeedForUser(user):
	cal = Calendar()
	cal.add('prodid', "-//%s's Keeper Calendar//getkeeper.com//" % user.name)
	cal.add('version', '2.0')

	weekAgo = date_util.now() - datetime.timedelta(days=7)
	entries = Entry.fetchEntries(user, label="#reminders", hidden=False, orderByString="remind_timestamp")
	entries = entries.exclude(remind_timestamp__lt=weekAgo)

	entryEvents = []
	for entry in entries:
		# if the date is the same, add the entry to the current entry event
		if len(entryEvents) > 0 and entryEvents[-1].equalToDateTime(entry.remind_timestamp):
			entryEvents[-1].addEntry(entry)
		else:
			entryEvents.append(EntryEvent(entry, user))

	for entryEvent in entryEvents:
		cal.add_component(entryEvent.asIcsEvent())

	return cal.to_ical()


class EntryEvent:
	entries = []
	user = None

	def __init__(self, entry, user):
		self.entries = [entry]
		self.user = user

	def addEntry(self, entry):
		if len(self.entries) > 0 and not self.equalToDateTime(entry.remind_timestamp):
			raise NameError("Tried to add events with conflicting remind_timestamp to EntryEvent. TimeStamps: %s, %s" % (
				entry.remind_timestamp, self.entries[0].remind_timestamp
			))

		self.entries.append(entry)

	def equalToDateTime(self, dt):
		if len(self.entries) == 0:
			return None

		myVDatetime = vDatetime(self.entries[0].remind_timestamp.replace(second=0)).to_ical()
		otherVDateTime = vDatetime(dt.replace(second=0)).to_ical()
		print "myVDatetime: %s otherVDateTime: %s" % (myVDatetime, otherVDateTime)
		return myVDatetime == otherVDateTime

	def asIcsEvent(self):
		event = Event()

		event.add('summary', ", ".join(map(lambda entry: entry.text, self.entries)))

		event.add('dtstart', self.entries[0].remind_timestamp.replace(second=0))
		event.add('dtend', self.entries[0].remind_timestamp.replace(second=0) + datetime.timedelta(hours=1))
		event.add('dtstamp', self.entries[0].added)  # this is not accurate, but shouldn't matter

		# people
		organizer = vCalAddress('MAILTO:support@getkeeper.com')
		organizer.params['cn'] = vText('Keeper')
		organizer.params['role'] = vText('CHAIR')
		event['organizer'] = organizer
		event['uid'] = "d".join(map(lambda entry: str(entry.id), self.entries))
		event.add('priority', 5)

		attendee = vCalAddress('SMS:' + self.user.phone_number)
		attendee.params['cn'] = vText(self.user.name)
		attendee.params['ROLE'] = vText('REQ-PARTICIPANT')
		event.add('attendee', attendee, encode=0)
		return event
