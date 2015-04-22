import logging
import httplib2
import os
import datetime
import dateutil.parser
import time

from django.http import HttpResponseRedirect

from oauth2client.client import flow_from_clientsecrets
from oauth2client.django_orm import Storage

from apiclient.discovery import build

from memfresh.models import User, ContactEntry, FollowUp, CredentialsModel

from strand import notifications_util
from peanut.settings import constants

# CLIENT_SECRETS, name of a file containing the OAuth 2.0 information for this
# application, including client_id and client_secret, which are found
# on the API Access tab on the Google APIs
# Console <http://code.google.com/apis/console>
CLIENT_SECRETS = os.path.join(os.path.dirname(__file__), 'client_secrets.json')


FLOW = flow_from_clientsecrets(
	CLIENT_SECRETS,
	scope='https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email',
	redirect_uri='http://dev.duffyapp.com/memfresh/oauth2callback')

def getUserRedirect(user):
	FLOW.params['state'] = user.id
	FLOW.params['access_type'] = 'offline'
	authorize_url = FLOW.step1_get_authorize_url()
	return HttpResponseRedirect(authorize_url)

def getService(user, serviceName):
	storage = Storage(CredentialsModel, 'user', user, 'credential')
	credential = storage.get()
	if credential is None or credential.invalid == True:
		return None
	else:
		http = httplib2.Http()
		http = credential.authorize(http)

		if serviceName == "calendar":
			service = build(serviceName, "v3", http=http)
		elif serviceName == "plus":
			service = build(serviceName, "v1", http=http)
		else:
			return None
			
		page_token = None
		return service

def getMostCompletedRecentEvent(service, timedelta):
	# get the next 12 hours of events
	now = datetime.datetime.utcnow()
	start_time = now - timedelta
	end_time = now
	tz_offset = - time.altzone / 3600
	if tz_offset < 0:
		tz_offset_str = "-%02d00" % abs(tz_offset)
	else:
		tz_offset_str = "+%02d00" % abs(tz_offset)
	start_time = start_time.strftime("%Y-%m-%dT%H:%M:%S") + tz_offset_str
	end_time = end_time.strftime("%Y-%m-%dT%H:%M:%S") + tz_offset_str

	print "Getting calendar events between: " + start_time + " and " + end_time

	events = service.events().list(calendarId='primary', timeMin=start_time, timeMax=end_time, singleEvents=True).execute()
	if "items" in events and len(events["items"]) > 0:
		events = sorted(events["items"], key=lambda x: dateutil.parser.parse(x['end']['dateTime']), reverse=True)
		if len(events) > 0:
			return events[0]
	return None

def getLastEventFollowUpsForUser(user):
	followUps = FollowUp.objects.filter(user=user).order_by("-added")[:1]
	if len(followUps) > 0:
		eventId = followUps[0].from_event_id
	followUps = FollowUp.objects.filter(user=user, from_event_id=eventId)
	return followUps

def getEventIdsWithFollowUps(user):
	followUps = FollowUp.objects.filter(user=user)
	eventIds = [followUp.from_event_id for followUp in followUps]
	return eventIds
	
def askForFollowUpForEvent(user, event):
	contacts = list()
	if "attendees" in event:
		for attendee in event["attendees"]:
			if attendee["email"] != user.email:
				contacts.append(attendee)
	if "organizer" in event and event["organizer"]["email"] != user.email:
		contacts.append(event["organizer"])

	for contact in contacts:
		if not ContactEntry.objects.filter(user=user, email=contact["email"]).exists():
			contactEntry = ContactEntry.objects.create(user=user, email=contact["email"], name=contact["displayName"])
		else:
			contactEntry = ContactEntry.objects.get(user=user, email=contact["email"])

		FollowUp.objects.create(user=user, contact=contactEntry, from_event_id=event["id"])

	if len(contacts) > 0:
		names = [contact["displayName"] for contact in contacts]
		msg = "What would you like to remember for next time with %s?" % ' or '.join(names)
		print msg
		notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, constants.TWILIO_MEMFRESH_PHONE_NUM)
