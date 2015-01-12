import json
import datetime
import pytz
import time
import logging

from phonenumber_field.phonenumber import PhoneNumber

from django.http import HttpResponse
from django.contrib.gis.geos import Point

from peanut.settings import constants

from common.models import Photo
from common.serializers import ActionWithUserNameSerializer
from common import serializers

logger = logging.getLogger(__name__)

class DuffyJsonEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		if isinstance(obj, PhoneNumber):
			return str(obj)

		if isinstance(obj, Point):
			return str(obj)

			
		return json.JSONEncoder.default(self, obj)

def getRequestData(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	return data

def returnFailure(response, msg):
	response['result'] = False
	response['debug'] = msg
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Get a datetime object or a int() Epoch timestamp and return a
	pretty string like 'an hour ago', 'Yesterday', '3 months ago',
	'just now', etc

	From: http://stackoverflow.com/questions/1551382/user-friendly-time-format-in-python
"""
def prettyDate(time=False):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	if type(time) is int:
		diff = now - datetime.datetime.fromtimestamp(time)
	elif isinstance(time, datetime.datetime):
		diff = now - time
	elif not time:
		diff = now - now
	second_diff = diff.seconds
	day_diff = diff.days

	if day_diff < 0:
		return ''

	if day_diff == 0:
		if second_diff < 60:
			return "just now"
		if second_diff < 120:
			return "a min ago"
		if second_diff < 3600:
			return str(second_diff / 60) + " mins ago"
		if second_diff < 7200:
			return "an hour ago"
		if second_diff < 86400:
			return str(second_diff / 3600) + " hours ago"
	if day_diff == 1:
		return "Yesterday"
	if day_diff < 7:
		return str(day_diff) + " days ago"
	if day_diff < 14:
		return "a week ago"
	if day_diff < 31:
		return str(day_diff / 7) + " weeks ago"
	if day_diff < 60:
		return "a month ago"
	if day_diff < 365:
		return str(day_diff / 30) + " months ago"
	if day_diff < 730:
		return "a year ago"
	return str(day_diff / 365) + " years ago"
