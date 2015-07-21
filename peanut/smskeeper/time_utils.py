import pytz

from common import date_util


def isDateOlderThan(dt, days=0, hours=0):
	if dt is None:
		return True
	now = date_util.now(pytz.utc)
	delta = now - dt
	return delta.days >= days and delta.seconds >= (hours * 60 * 60)


def daysAndHoursAgo(dt):
	delta = date_util.now(pytz.utc) - dt
	return delta.days, (delta.seconds / 60 / 60)


def totalHoursAgo(dt):
	delta = date_util.now(pytz.utc) - dt
	return (delta.total_seconds() / 60 / 60)
