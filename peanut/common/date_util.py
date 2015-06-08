import pytz
import datetime


def now(tz=pytz.utc):
	return utcnow().astimezone(tz)


def utcnow():
	return datetime.datetime.now(pytz.utc)
