import random
import logging
import os

from django.db.models import Q

from common.models import User, FriendConnection, ContactEntry, StrandInvite

logger = logging.getLogger(__name__)


def initNewUser(user, fromSmsAuth, buildNum):
	logger.debug("Initing new user %s" % user.id)

	# Now pre-populate friends who this user was invited by
	invitedBy = ContactEntry.objects.filter(phone_number=user.phone_number).filter(contact_type="invited").exclude(skip=True)
	
	for invite in invitedBy:
		FriendConnection.addConnection(user, invite.user)
		
	# Now fill in strand invites for this phone number
	strandInvites = StrandInvite.objects.filter(phone_number=user.phone_number).filter(invited_user__isnull=True).filter(accepted_user__isnull=True)
	seenInvitesFromUsers = list()
	for strandInvite in strandInvites:
		strandInvite.invited_user = user

		# Temp solution for using invites to hold incoming pictures
		if fromSmsAuth and (not buildNum or (buildNum and int(buildNum) > 4805)):
			strandInvite.accepted_user = user
			
			if user not in strandInvite.strand.users.all():
				action = Action.objects.create(user=user, strand=strandInvite.strand, action_type=constants.ACTION_TYPE_JOIN_STRAND)
				strandInvite.strand.users.add(user)

		strandInvite.save()
		
	if len(strandInvites) > 0:
		user.first_run_sync_timestamp = strandInvites[0].strand.first_photo_time

		logger.debug("Updated %s invites with user id %s and set first_run_sync_timestamp to %s" % (len(strandInvites), user.id, user.first_run_sync_timestamp))

	contacts = ContactEntry.objects.filter(phone_number = user.phone_number).exclude(user=user).exclude(skip=True).filter(user__product_id=2)
	friends = set([contact.user for contact in contacts])

	FriendConnection.addNewConnections(user, friends)

	# Create directory for photos
	# TODO(Derek): Might want to move to a more common location if more places that we create users
	try:
		userBasePath = user.getUserDataPath()
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)
"""
	Helper Method for auth_phone

	Strand specific code for creating a user.  If a user already exists, this will
	archive the old one by changing the phone number to an archive format (2352+15555555555)

	This also updates the SmsAuth object to point to this user

	Lastly, this creates the local directory

	TODO(Derek):  If we create users in more places, might want to move this
"""
def createStrandUserThroughSmsAuth(phoneNumber, displayName, smsAuth, buildNum):
	try:
		user = User.objects.get(Q(phone_number=phoneNumber) & Q(product_id=2))
		
		if user.has_sms_authed:
			# This increments the install number, which we use to track which photos were uploaded when
			user.install_num = user.install_num + 1
		else:
			user.install_num = 0
			user.has_sms_authed = True
		user.save()

		return user
	except User.DoesNotExist:
		pass

	# TODO(Derek): Make this more interesting when we add auth to the APIs
	authToken = random.randrange(10000, 10000000)

	user = User.objects.create(phone_number = phoneNumber, has_sms_authed= True, display_name = displayName, product_id = 2, auth_token = str(authToken))

	initNewUser(user, True, buildNum)
	
	# Actually, we might not have an sms auth due to fake users
	if smsAuth:
		smsAuth.user_created = user
		smsAuth.save()

	logger.info("Created new user %s from sms auth %s" % (user, smsAuth.id))

	return user
