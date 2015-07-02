from rest_framework import serializers
from smskeeper import models


class EntrySerializer(serializers.ModelSerializer):
	class Meta:
		model = models.Entry
		fields = (
			'id',
			'creator',
			'users',
			'label',
			'text',
			'img_url',
			'remind_timestamp',
			'remind_last_notified',
			'hidden',
			'added',
			'updated'
		)

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
