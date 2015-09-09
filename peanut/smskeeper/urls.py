"""Main project URL definitions."""
from django.conf.urls import patterns, url
from smskeeper import views

urlpatterns = patterns(
	'',
	# external services
	url(r'^incoming_sms', 'smskeeper.views.incoming_sms'),
	url(r'^keeper_app', 'smskeeper.views.keeper_app'),
	url(r'^history', 'smskeeper.views.history'),
	url(r'^review/$', 'smskeeper.views.review'),
	url(r'^send_sms', 'smskeeper.views.send_sms'),
	url(r'^send_media', 'smskeeper.views.send_media'),
	url(r'^message_feed', 'smskeeper.views.message_feed'),
	url(r'^unknown_messages_feed', 'smskeeper.views.unknown_messages_feed'),
	url(r'^classified_messages_feed', 'smskeeper.views.classified_messages_feed'),
	url(r'^entry_feed', 'smskeeper.views.entry_feed'),
	url(r'^toggle_paused', 'smskeeper.views.toggle_paused'),
	url(r'^dashboard_feed', 'smskeeper.views.dashboard_feed'),
	url(r'^dashboard', 'smskeeper.views.dashboard'),
	url(r'^resend_msg', 'smskeeper.views.resend_msg'),
	url(r'^signup_from_website', 'smskeeper.views.signup_from_website'),
	url(r'^entry/$', views.EntryList.as_view()),
	url(r'^entry/(?P<pk>[0-9]+)/$', views.EntryDetail.as_view()),
	url(r'^review_feed/$', views.ReviewFeed.as_view()),
	url(r'^message/(?P<pk>[0-9]+)/$', views.MessageDetail.as_view()),
	url(r'^simulation_result/$', views.SimulationResultList.as_view()),
	url(r'^simulation_dash/$', 'smskeeper.views.simulation_dash'),
	url(r'^message_classification[.]csv$', 'smskeeper.views.message_classification_csv'),
	url(r'^classified_users$', 'smskeeper.views.classified_users'),
	url(r'^approved_todos$', 'smskeeper.views.approved_todos'),
	url(r'^update_stripe_info', 'smskeeper.views.update_stripe_info'),
)
