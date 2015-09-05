import pytz
import datetime
import dateutil.parser


# Returns seconds since epoch
def unixTime(dt):
	epoch = datetime.datetime.utcfromtimestamp(0).replace(tzinfo=pytz.utc)
	delta = dt - epoch
	return int(delta.total_seconds())


def now(tz=pytz.utc):
	return utcnow().astimezone(tz)


def utcnow():
	return datetime.datetime.now(pytz.utc)

def fromIsoString(string):
	return dateutil.parser.parse(string)