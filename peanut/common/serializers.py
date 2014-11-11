from rest_framework import serializers
from common.models import Photo, User, Action, ContactEntry, StrandInvite, Strand

from rest_framework import renderers
from rest_framework.parsers import BaseParser

from django.db import connection

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

class StrandInviteSerializer(serializers.ModelSerializer):
	class Meta:
		model = StrandInvite

class BulkStrandInviteSerializer(serializers.Serializer):
	invites = StrandInviteSerializer(many=True)

	# key in the json that links to the list of objects
	bulk_key = 'invites'

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
	actionData['strand'] = action.strand.id
	actionData['photo'] = action.photo.id
	actionData['text'] = action.text

	# TODO(Derek): remove this once we don't need it
	actionData['user_display_name'] = action.getUserDisplayName()

	return actionData