"""Main project URL definitions."""
from django.conf.urls import patterns, include, url
from smskeeper import views

urlpatterns = patterns(
	'',
	# external services
	url(r'^incoming_sms', 'smskeeper.views.incoming_sms'),
	url(r'^all_notes', 'smskeeper.views.all_notes'),
	url(r'^history', 'smskeeper.views.history'),
	url(r'^send_sms', 'smskeeper.views.send_sms'),
)
