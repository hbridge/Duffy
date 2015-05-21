from datetime import datetime
import pytz

def isDateOlderThan(dt, days=0, hours=0):
	if dt is None:
		return True
	now = datetime.now(pytz.utc)
	delta = now - dt
	return delta.days >= days and delta.seconds >= (hours * 60 * 60)

def daysAndHoursAgo(dt):
	delta = datetime.now(pytz.utc) - dt
	return delta.days, (delta.seconds / 60 / 60)
