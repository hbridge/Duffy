from rest_framework import serializers
from smskeeper import models


class EntrySerializer(serializers.ModelSerializer):
	class Meta:
		model = models.Entry


class UserSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.User


class ReviewEntrySerializer(serializers.ModelSerializer):
	creator = UserSerializer(many=False, read_only=True)

	class Meta:
		model = models.Entry

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
