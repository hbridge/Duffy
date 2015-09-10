from rest_framework import serializers
from smskeeper import models
from rest_framework_bulk import (
    BulkListSerializer,
    BulkSerializerMixin,
)

import logging
logger = logging.getLogger(__name__)


class EntrySerializer(serializers.ModelSerializer):
	# need this for the custom review page to show entries in the right timezone
	creatorName = serializers.CharField(source='creator.name', read_only=True)
	creatorTimezone = serializers.CharField(source='creator.getTimezone', read_only=True)
	creatorDigestHour = serializers.CharField(source='creator.getDigestHour', read_only=True)
	creatorDigestMinute = serializers.CharField(source='creator.getDigestMinute', read_only=True)

	class Meta:
		model = models.Entry


class HistoricalEntrySerializer(serializers.ModelSerializer):
	class Meta:
		model = models.Entry
		fields = (
			'id',
			'text',
			'remind_timestamp',
		)


class UserSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.User


class HistoricalUserSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.User
		fields = (
			'completed_tutorial',
			'product_id',
			'activated',
			'paused',
			'state',
			'last_state',
			'state_data',
			'timezone',
			'postal_code',
			'signature_num_lines',
			'added',
		)


class MessageSerializer(serializers.ModelSerializer):
	class Meta:
		model = models.Message


class ClassifiedMessageSerializer(serializers.ModelSerializer):
	activeEntriesSnapshot = HistoricalEntrySerializer(many=True)
	userSnapshot = HistoricalUserSerializer()
	body = serializers.CharField(source='getBody', read_only=True)

	class Meta:
		model = models.Message


class SimulationResultSerializer(BulkSerializerMixin, serializers.ModelSerializer):
	class Meta:
		model = models.SimulationResult
		list_serializer_class = BulkListSerializer


class SimulationRunSummarySerializer(serializers.ModelSerializer):
	simResults = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
	numCorrect = serializers.IntegerField(read_only=True)
	numIncorrect = serializers.IntegerField(read_only=True)

	class Meta:
		model = models.SimulationRun


class DetailedSimulationRunSerializer(serializers.ModelSerializer):
	simResults = SimulationResultSerializer(many=True)

	class Meta:
		model = models.SimulationRun

	def create(self, validated_data):
		sim_results = validated_data.pop('simResults')
		sim_run = models.SimulationRun.objects.create(**validated_data)

		simResultModels = []
		for sim_result in sim_results:
			simResultModel = models.SimulationResult(run=sim_run, **sim_result)
			simResultModels.append(simResultModel)
			if len(simResultModels) > 500:
				models.SimulationResult.objects.bulk_create(simResultModels)
				simResultModels = []

		if len(simResultModels) > 0:
			models.SimulationResult.objects.bulk_create(simResultModels)

		return sim_run
