from rest_framework import serializers
from smskeeper import models


class EntrySerializer(serializers.ModelSerializer):
	# need this for the custom review page to show entries in the right timezone
	creatorName = serializers.CharField(source='creator.name', read_only=True)
	creatorTimezone = serializers.CharField(source='creator.getTimezone', read_only=True)
	creatorDigestHour = serializers.CharField(source='creator.getDigestHour', read_only=True)
	creatorDigestMinute = serializers.CharField(source='creator.getDigestMinute', read_only=True)

	class Meta:
		model = models.Entry


class UserSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.User


class MessageSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.Message
		fields = (
			'id',
			'user',
			'msg_json',
			'incoming',
			'manual',
			'classification',
			'added',
			'updated'
		)
