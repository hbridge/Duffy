from rest_framework import serializers
from common.models import Photo, User, PhotoAction


class PhotoSerializer(serializers.ModelSerializer):
	full_image_path = serializers.Field(source='getFullUrlImagePath')

	class Meta:
		model = Photo
		fields = ('id', 'user', 'time_taken', 'metadata', 'location_data', 'iphone_faceboxes_topleft', 'iphone_hash', 'full_filename', 'thumb_filename', 'file_key', 'bulk_batch_key', 'is_local', 'full_image_path')

class PhotoForApiSerializer(serializers.ModelSerializer):
	full_image_path = serializers.Field(source='getFullUrlImagePath')
	thumb_image_path = serializers.Field(source='getThumbUrlImagePath')
	user_display_name = serializers.Field(source='getUserDisplayName')

	class Meta:
		model = Photo
		fields = ('id', 'user', 'time_taken','full_image_path', 'thumb_image_path', 'user_display_name',)


class UserSerializer(serializers.ModelSerializer):
	class Meta:
		model = User
		fields = ('id', 'display_name', 'phone_number', 'auth_token', 'invites_remaining')

class PhotoActionWithUserNameSerializer(serializers.ModelSerializer):
	user_display_name = serializers.Field('getUserDisplayName')
	
	class Meta:
		model = PhotoAction
		fields = ('id', 'photo', 'user', 'user_display_name', 'action_type')

	
