"""Main project URL definitions."""
from django.conf.urls import patterns, include, url
from memfresh import views

urlpatterns = patterns(
	'',
	url(r'^emails/',include('django_inbound_email.urls')),
	(r'^get_followup', 'memfresh.views.get_followup'),
	(r'^do_auth', 'memfresh.views.do_auth'),
	(r'^oauth2callback', 'memfresh.views.auth_return'),

	# external services
	url(r'^incoming_sms.xml', 'memfresh.views.incoming_sms'),
)