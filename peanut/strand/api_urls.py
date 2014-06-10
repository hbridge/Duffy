from django.conf.urls import patterns, url
from rest_framework.urlpatterns import format_suffix_patterns
from strand import api_views

urlpatterns = patterns('strand.api_views',
	url(r'^neighbors', 'neighbors'),
)

urlpatterns = format_suffix_patterns(urlpatterns)