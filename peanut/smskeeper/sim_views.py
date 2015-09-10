import json
import os
import sys
import logging
import re

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.contrib.auth.decorators import login_required
from django.core.serializers.json import DjangoJSONEncoder
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import authentication
from rest_framework import generics
from rest_framework import permissions
from rest_framework_bulk import ListBulkCreateUpdateDestroyAPIView
from smskeeper import keeper_constants
from smskeeper.models import Message
from smskeeper.models import SimulationResult
from smskeeper.models import SimulationRun
from smskeeper.models import SimulationClassDetails
from smskeeper.serializers import ClassifiedMessageSerializer
from smskeeper.serializers import DetailedSimulationRunSerializer
from smskeeper.serializers import SimulationResultSerializer
from smskeeper.serializers import SimulationRunSummarySerializer
from smskeeper.views import renderReact
logger = logging.getLogger(__name__)


def cleanBodyText(text):
	result = re.sub(ur'[\n"\u201d]', '', text)
	return result

@login_required(login_url='/admin/login/')
def message_classification_csv(request):
	classified_messages = Message.objects.filter(
		classification__isnull=False).exclude(classification__in='nocategory').order_by("id")

	# column headers
	response = 'text, classification\n'

	# message rows
	for message in classified_messages:
		if message.classification == "nocategory" or not message.getBody():
			continue
		response += '"%s",%s\n' % (cleanBodyText(message.getBody()), message.classification)

	return HttpResponse(response, content_type="text/text", status=200)

def classified_messages_feed(request):
	classified_messages = Message.objects.filter(incoming=True).order_by('user')
	classified_messages = classified_messages.exclude(classification__isnull=True)
	classified_messages = classified_messages.exclude(classification__exact='')
	classified_messages = classified_messages.exclude(classification=keeper_constants.CLASS_NONE)
	serializer = ClassifiedMessageSerializer(classified_messages, many=True)
	return HttpResponse(json.dumps(serializer.data, cls=DjangoJSONEncoder), content_type="text/json", status=200)


class SimulationResultList(ListBulkCreateUpdateDestroyAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = SimulationResult.objects.all()
	serializer_class = SimulationResultSerializer

class SimulationResultDetail(generics.RetrieveUpdateDestroyAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = SimulationResult.objects.all()
	serializer_class = SimulationResultSerializer

class SimulationRunDetail(generics.RetrieveUpdateDestroyAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = SimulationRun.objects.all()
	serializer_class = DetailedSimulationRunSerializer

class SimulationRunList(generics.ListAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = SimulationRun.objects.all()
	serializer_class = SimulationRunSummarySerializer


class SimulationRunCreate(generics.CreateAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = SimulationRun.objects.all()
	serializer_class = DetailedSimulationRunSerializer


def simulation_classes_summary(request, simId):
	simRun = get_object_or_404(SimulationRun, id=simId)
	simResults = simRun.simResults()
	classDetails = SimulationResult.simulationClassDetails(simResults)
	summaryDicts = SimulationClassDetails.dictRepsForSummaries(classDetails)
	return HttpResponse(json.dumps(summaryDicts, cls=DjangoJSONEncoder), content_type="text/json", status=200)


def simulation_class_details(request, simId, msgClass):
	simRun = get_object_or_404(SimulationRun, id=simId)
	simResults = simRun.simResults()
	classDetails = SimulationResult.simulationClassDetails(simResults)
	detailsDict = classDetails[msgClass.encode('ascii')].fullJsonDict()
	return HttpResponse(json.dumps(detailsDict, cls=DjangoJSONEncoder), content_type="text/json", status=200)


@login_required(login_url='/admin/login/')
def simulation_dash(request):
	return renderReact(
		request,
		'simulation_dash',
		'simulation_dash.html',
		requiresUser=False,
		context={"classifications": keeper_constants.CLASS_MENU_OPTIONS}
	)
