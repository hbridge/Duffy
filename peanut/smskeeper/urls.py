"""Main project URL definitions."""
from django.conf.urls import patterns, include, url
from smskeeper import views

urlpatterns = patterns(
	'',
	# external services
	url(r'^incoming_sms', 'smskeeper.views.incoming_sms'),
)