"""Main project URL definitions."""
from django.conf.urls import patterns, url

urlpatterns = patterns(
	'',
	# external services
	url(r'^incoming_sms', 'smskeeper.views.incoming_sms'),
	url(r'^all_notes', 'smskeeper.views.all_notes'),
	url(r'^history', 'smskeeper.views.history'),
	url(r'^send_sms', 'smskeeper.views.send_sms'),
	url(r'^message_feed', 'smskeeper.views.message_feed'),
	url(r'^toggle_paused', 'smskeeper.views.toggle_paused'),
	url(r'^dashboard_feed', 'smskeeper.views.dashboard_feed'),
	url(r'^dashboard', 'smskeeper.views.dashboard'),
	url(r'^resend_msg', 'smskeeper.views.resend_msg'),
	url(r'^signup_from_website', 'smskeeper.views.signup_from_website')
)
