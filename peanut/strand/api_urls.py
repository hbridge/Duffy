from django.conf.urls import patterns, url
from rest_framework.urlpatterns import format_suffix_patterns
from rest_framework.generics import RetrieveUpdateDestroyAPIView

# If you're changing these, don't forget to change them below
from strand import api_views as strand_api_views
from arbus import api_views as arbus_api_views

from common.models import PhotoAction

urlpatterns = patterns('',
	url(r'^get_user', 'arbus.api_views.get_user', {'productId': '1'}),
	url(r'^create_user', 'arbus.api_views.create_user', {'productId': '1'}),
	url(r'^photos/$', arbus_api_views.PhotoAPI.as_view()),
	url(r'^photos/(?P<photoId>[0-9]+)/$', arbus_api_views.PhotoAPI.as_view()),
	url(r'^photos/bulk/$', arbus_api_views.PhotoBulkAPI.as_view()),
	
	url(r'^neighbors', 'strand.api_views.neighbors'),
	url(r'^get_joinable_strands', 'strand.api_views.get_joinable_strands'),
	url(r'^get_new_photos', 'strand.api_views.get_new_photos'),

	url(r'^register_apns_token', 'strand.api_views.register_apns_token'),
	url(r'^update_user_location', 'strand.api_views.update_user_location'),
	url(r'^get_nearby_friends_message', 'strand.api_views.get_nearby_friends_message'),

	url(r'^send_sms_code', 'strand.api_views.send_sms_code'),
	url(r'^auth_phone', 'strand.api_views.auth_phone'),

	url(r'^photo_actions/$', strand_api_views.CreatePhotoActionAPI.as_view(model=PhotoAction, lookup_field='id')),
	url(r'^photo_actions/(?P<id>[0-9]+)/$', RetrieveUpdateDestroyAPIView.as_view(model=PhotoAction, lookup_field='id')),

	# experimental
	url(r'^send_notifications_test', 'strand.api_views.send_notifications_test'),
	url(r'^send_sms_test', 'strand.api_views.send_sms_test'),	
)

urlpatterns = format_suffix_patterns(urlpatterns)