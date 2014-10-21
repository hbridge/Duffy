from rest_framework import serializers
from common.models import Photo, User, Action, ContactEntry, StrandInvite, Strand

from rest_framework import renderers
from rest_framework.parsers import BaseParser


class PhotoSerializer(serializers.ModelSerializer):
	full_image_path = serializers.Field(source='getFullUrlImagePath')

	class Meta:
		model = Photo

class UserSerializer(serializers.ModelSerializer):
	partial = True
	display_name = serializers.CharField(required=False)
	
	class Meta:
		model = User
		fields = ('id', 'display_name', 'phone_number', 'phone_id', 'auth_token', 'device_token', 'last_location_point', 'last_location_accuracy', 'first_run_sync_timestamp', 'first_run_sync_count', 'invites_remaining', 'invites_sent', 'added')

class ActionWithUserNameSerializer(serializers.ModelSerializer):
	user_display_name = serializers.Field('getUserDisplayName')
	
	class Meta:
		model = Action
		fields = ('id', 'photo', 'user', 'user_display_name', 'action_type')
	
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