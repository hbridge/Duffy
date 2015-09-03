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

from django_ical.views import ICalFeed
from icalendar import vDatetime

from django.shortcuts import get_object_or_404
import emoji


def icsFeed(request, key):
	keys = ["K" + key, "P" + key]
	try:
		user = User.objects.get(key__in=keys)
		return EventFeed(request, user)
	except User.DoesNotExist:
		return HttpResponse(json.dumps({"Errors": "User not found"}), content_type="text/json", status=400)


class EventFeed(ICalFeed):
	product_id = "-//Keeper Calendar//getkeeper.com//"
	title = emoji.emojize("Keeper :raising_hand:", use_aliases=True)

	def get_object(self, request, key):
		keys = ["K" + key, "P" + key]
		return get_object_or_404(User, key__in=keys)

	def items(self, user):
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
		return entryEvents

	def item_title(self, item):
		return item.title()

	def item_description(self, item):
		return item.description()

	def item_start_datetime(self, item):
		return item.start_datetime()

	def item_end_datetime(self, item):
		return item.end_datetime()


class EntryEvent:
	entries = []
	user = None

	def __init__(self, entry, user):
		self.entries = [entry]
		self.user = user

	# feed properties
	def title(self):
		return ", ".join(map(lambda entry: entry.text, self.entries))

	def description(self):
		return ""

	def start_datetime(self):
		return self.entries[0].remind_timestamp.replace(second=0)

	def end_datetime(self):
		return self.entries[0].remind_timestamp.replace(second=0) + datetime.timedelta(hours=1)

	def get_absolute_url(self):
		return "/" + self.user.key + "/" + "d".join(map(lambda entry: str(entry.id), self.entries))

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
