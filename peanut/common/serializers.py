import logging
import time

from rest_framework import serializers
from common.models import Photo, User, Action, ContactEntry, Strand, ShareInstance

from rest_framework import renderers
from rest_framework.parsers import BaseParser

from strand import strands_util
from common import stats_util

from django.db import connection

from peanut.settings import constants

logger = logging.getLogger(__name__)

class PhotoSerializer(serializers.ModelSerializer):
	full_image_path = serializers.Field(source='getFullUrlImagePath')

	class Meta:
		model = Photo

class UserSerializer(serializers.ModelSerializer):
	partial = True
	display_name = serializers.CharField(required=False)
	
	class Meta:
		model = User

class ActionWithUserNameSerializer(serializers.ModelSerializer):
	#user_display_name = serializers.Field('getUserDisplayName')
	
	class Meta:
		model = Action
		fields = ('id', 'photo', 'user', 'action_type', 'text')
	
class ContactEntrySerializer(serializers.ModelSerializer):
	phone_number = serializers.CharField()

	class Meta:
		model = ContactEntry

class BulkContactEntrySerializer(serializers.Serializer):
	contacts = ContactEntrySerializer(many=True)

	# key in the json that links to the list of objects
	bulk_key = 'contacts'

class BulkUserSerializer(serializers.Serializer):
	users = UserSerializer(many=True)

	bulk_key = 'users'

class ShareInstanceSerializer(serializers.ModelSerializer):
	lookup_field = 'id'
	
	class Meta:
		model = ShareInstance

class BulkShareInstanceSerializer(serializers.Serializer):
	share_instances = ShareInstanceSerializer(many=True)

	# key in the json that links to the list of objects
	bulk_key = 'share_instances'

def objectDataForShareInstance(shareInstance, actions, user):
	shareInstanceData = dict()
	shareInstanceData['type'] = "photo"
	shareInstanceData['user'] = shareInstance.user_id
	shareInstanceData['id'] = shareInstance.photo_id
	shareInstanceData['time_taken'] = shareInstance.photo.time_taken
	shareInstanceData['full_image_path'] = shareInstance.photo.getFullUrlImagePath()
	shareInstanceData['thumb_image_path'] = shareInstance.photo.getThumbUrlImagePath()
	shareInstanceData['actor_ids'] = [actor.id for actor in shareInstance.users.all()]
	shareInstanceData['debug_last_action_timestamp'] = shareInstance.last_action_timestamp
	shareInstanceData['shared_at_timestamp'] = shareInstance.shared_at_timestamp
	shareInstanceData['share_instance'] = shareInstance.id
	shareInstanceData['full_width'] = shareInstance.photo.full_width
	shareInstanceData['full_height'] = shareInstance.photo.full_height

	publicActions = list()
	userEvalAction = None
	for action in actions:
		if action.action_type != constants.ACTION_TYPE_PHOTO_EVALUATED:
			publicActions.append(action)
		elif action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED and action.user_id == user.id:
			userEvalAction = action

	if userEvalAction or shareInstance.user_id == user.id:
		shareInstanceData['evaluated'] = True
		if userEvalAction:
			shareInstanceData['evaluated_time'] = userEvalAction.added
		else:
			shareInstanceData['evaluated_time'] = shareInstance.shared_at_timestamp
	else:
		shareInstanceData['evaluated'] = False
		
	shareInstanceData['actions'] = [actionDataForShareInstance(action) for action in publicActions]

	return shareInstanceData


def objectDataForPrivateStrand(user, strand, friends, includeAll, suggestionType, interestedUsersByStrandId, matchReasonsByStrandId, actionsByPhotoId):
	strandData = dict()
	strandData['id'] = strand.id
	if strand.id in interestedUsersByStrandId:
		interestedUsers = interestedUsersByStrandId[strand.id]
		strandData['match_reasons'] = matchReasonsByStrandId[strand.id]
		strandData['actors'] = actorsData(friends, interestedUsers)
		strandData['actor_ids'] = User.getIds(interestedUsers)

	strandData['strand_id'] = strand.id
	strandData['time_taken'] = int(time.mktime(strand.first_photo_time.timetuple()))
	strandData['suggestion_type'] = suggestionType
	strandData['suggestible'] = True
	strandData['location'] = strands_util.getLocationForStrand(strand)
	strandData['type'] = 'section'

	strandData['objects'] = list()

	photosIncluded = 0
	for photo in strand.photos.all():
		evaled = False
		if photo.id in actionsByPhotoId:
			for action in actionsByPhotoId[photo.id]:
				if action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED:
					evaled = True
		if (not evaled or includeAll) and photo.install_num == user.install_num:
			strandData['objects'].append(photoDataForApiSerializer(photo))
			photosIncluded += 1

	if photosIncluded == 0:
		return None

	return strandData

def actionDataForShareInstance(action):
	actionData = dict()
	actionData['id'] = action.id
	actionData['user'] = action.user_id
	actionData['time_stamp'] = action.added
	actionData['action_type'] = action.action_type
	actionData['text'] = action.text

	return actionData

def photoDataForApiSerializer(photo):
	photoData = dict()
	photoData['id'] = photo.id
	photoData['user'] = photo.user_id
	photoData['time_taken'] = int(time.mktime(photo.time_taken.timetuple()))
	photoData['local_time_taken'] = None
	photoData['full_image_path'] = photo.getFullUrlImagePath()
	photoData['thumb_image_path'] = photo.getThumbUrlImagePath()
	photoData['user_display_name'] = photo.getUserDisplayName()
	photoData['full_width'] = photo.full_width
	photoData['full_height'] = photo.full_height
	photoData['type'] = 'photo'

	return photoData

def actionDataOfActionApiSerializer(user, action):
	# Assumes that the list of actions don't have any done by the current user
	actionData = dict()

	# Only show favorites if its on something the user shared
	if (action.action_type == constants.ACTION_TYPE_FAVORITE and
		action.share_instance.user_id != user.id):
		return None
		
	actionData['id'] = action.id
	actionData['user'] = action.user_id
	actionData['time_stamp'] = action.added
	actionData['action_type'] = action.action_type
	actionData['share_instance'] = action.share_instance_id
	actionData['photo'] = action.photo_id
	actionData['text'] = action.text

	return actionData


def actionDataOfShareInstanceApiSerializer(user, shareInstance):
	# Assumes that the list of actions don't have any done by the current user
	actionData = dict()

	# Only return data for shares that other people do
	if shareInstance.user_id == user.id:
		return None
	
	# Don't try this at home.  We need a unique id but we don't create an action for a shared instance
	# So create a pretty unique one here
	actionData['id'] = shareInstance.id + 1000000000000
	actionData['user'] = shareInstance.user_id
	actionData['time_stamp'] = shareInstance.shared_at_timestamp
	actionData['action_type'] = constants.ACTION_TYPE_SHARED_PHOTOS
	actionData['share_instance'] = shareInstance.id
	actionData['photo'] = shareInstance.photo_id
	actionData['text'] = "Shared a photo"

	return actionData

def actorsData(friends, users, includePhone = True):
	if not isinstance(users, list) and not isinstance(users, set):
		users = [users]

	userData = list()

	for user in users:
		if user in friends:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_FRIEND
		else:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_USER
		
		entry = {'display_name': user.display_name, 'id': user.id, constants.FEED_OBJECT_TYPE_RELATIONSHIP: relationship}

		if includePhone:
			entry['phone_number'] = user.phone_number

		userData.append(entry)

	return userData