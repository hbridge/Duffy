import logging

from rest_framework import serializers
from common.models import Photo, User, Action, ContactEntry, StrandInvite, Strand, ShareInstance

from rest_framework import renderers
from rest_framework.parsers import BaseParser

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


class StrandInviteSerializer(serializers.ModelSerializer):
	class Meta:
		model = StrandInvite

class BulkStrandInviteSerializer(serializers.Serializer):
	invites = StrandInviteSerializer(many=True)

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
	shareInstanceData['last_action_timestamp'] = shareInstance.last_action_timestamp
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

	if userEvalAction:
		shareInstanceData['evaluated'] = True
		shareInstanceData['evaluated_time'] = action.added
	else:
		shareInstanceData['evaluated'] = False
		
	shareInstanceData['actions'] = [actionDataForShareInstance(action) for action in publicActions]

	return shareInstanceData

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
	photoData['time_taken'] = photo.time_taken
	photoData['local_time_taken'] = None
	photoData['full_image_path'] = photo.getFullUrlImagePath()
	photoData['thumb_image_path'] = photo.getThumbUrlImagePath()
	photoData['user_display_name'] = photo.getUserDisplayName()
	photoData['full_width'] = photo.full_width
	photoData['full_height'] = photo.full_height

	return photoData

def actionDataForApiSerializer(action):
	actionData = dict()
	actionData['id'] = action.id
	actionData['user'] = action.user_id
	actionData['time_stamp'] = action.added
	actionData['action_type'] = action.action_type
	actionData['strand'] = action.strand_id

	# TODO(Derek): This fetching of photos.all() can be removed in December once we've gone through a couple weeks of writing
	#   out the photo element for Add actions
	if action.action_type == constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND or action.action_type == constants.ACTION_TYPE_CREATE_STRAND and not action.photo:
		if len(action.photos.all()) == 0 and action.action_type == constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND:
			logger.error("Found action %s that is an add action with no photos.  Please delete this." % action.id)
		else:
			actionData['photo'] = action.photos.all()[0].id
			# Always make the client think this is add photos action
			actionData['action_type'] = constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND
	else:
		actionData['photo'] = action.photo_id
		
	actionData['text'] = action.text

	# TODO(Derek): remove this once we don't need it.
	#   That happens if we are caching this somewhere else and can add in or the client
	#   uses some other mapping than in the action itself
	actionData['user_display_name'] = action.getUserDisplayName()
	actionData['user_phone_number'] = action.getUserPhoneNumber()

	return actionData