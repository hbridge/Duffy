from rest_framework import serializers
from photos.models import Photo


class PhotoSerializer(serializers.ModelSerializer):
	class Meta:
		model = Photo
		fields = ('id', 'user', 'time_taken', 'metadata', 'location_data', 'iphone_faceboxes_topleft')