from rest_framework import serializers
from common.models import Photo, User, SimplePhoto


class PhotoSerializer(serializers.ModelSerializer):
	class Meta:
		model = Photo
		fields = ('id', 'user', 'time_taken', 'metadata', 'location_data', 'iphone_faceboxes_topleft', 'iphone_hash', 'full_filename', 'thumb_filename', 'file_key', 'bulk_batch_key', 'is_local')

class UserSerializer(serializers.ModelSerializer):
	class Meta:
		model = User
		fields = ('id', 'first_name')