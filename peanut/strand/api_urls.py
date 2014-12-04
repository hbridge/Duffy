from django.conf.urls import patterns, url
from rest_framework.urlpatterns import format_suffix_patterns
from rest_framework.generics import RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView, CreateAPIView

# If you're changing these, don't forget to change them below
from strand import api_views as strand_api_views
from strand import rest_api_views as strand_rest_api_views
from arbus import api_views as arbus_api_views

from common.models import User, ContactEntry, Strand, StrandInvite, Action, SharedStrand
from common.serializers import UserSerializer

urlpatterns = patterns('',
	url(r'^unshared_strands', 'strand.api_views.private_strands'),
	url(r'^strand_inbox', 'strand.api_views.strand_inbox'),
	url(r'^swaps', 'strand.api_views.swaps'),
	url(r'^actions_list', 'strand.api_views.actions_list'),

	url(r'^register_apns_token', 'strand.api_views.register_apns_token'),
	url(r'^update_user_location', 'strand.api_views.update_user_location'),

	url(r'^send_sms_code', 'strand.api_views.send_sms_code'),
	url(r'^auth_phone', 'strand.api_views.auth_phone'),

	# REST
	url(r'^photos/$', strand_rest_api_views.PhotoAPI.as_view()),
	url(r'^photos/(?P<photoId>[0-9]+)/$', strand_rest_api_views.PhotoAPI.as_view()),
	url(r'^photos/bulk/$', strand_rest_api_views.PhotoBulkAPI.as_view()),
	
	url(r'^actions/$', strand_rest_api_views.CreateActionAPI.as_view(model=Action, lookup_field='id')),
	url(r'^actions/(?P<id>[0-9]+)/$', RetrieveUpdateDestroyAPIView.as_view(model=Action, lookup_field='id')),

	url(r'^users/(?P<id>[0-9]+)/$', strand_rest_api_views.RetrieveUpdateUserAPI.as_view(model=User, lookup_field='id', serializer_class=UserSerializer)),

	url(r'^contacts/$', strand_rest_api_views.ContactEntryBulkAPI.as_view()),

	url(r'^strands/$', strand_rest_api_views.CreateStrandAPI.as_view(model=Strand, lookup_field='id')),	
	url(r'^strands/(?P<id>[0-9]+)/$', strand_rest_api_views.RetrieveUpdateDestroyStrandAPI.as_view(model=Strand, lookup_field='id')),

	url(r'^strand_invite/$', strand_rest_api_views.StrandInviteBulkAPI.as_view()),
	url(r'^strand_invite/(?P<id>[0-9]+)/$', strand_rest_api_views.RetrieveUpdateDestroyStrandInviteAPI.as_view(model=StrandInvite, lookup_field='id')),

	# Note: We have to create custom API views since we include build os in the json, so we have to use a specific key
	url(r'^shared_strand/$', strand_rest_api_views.KeyedCreateAPIView.as_view(model=SharedStrand, key="shared_strand")),

	# experimental
	url(r'^send_notifications_test', 'strand.api_views.send_notifications_test'),
	url(r'^send_sms_test', 'strand.api_views.send_sms_test'),
)

urlpatterns = format_suffix_patterns(urlpatterns)