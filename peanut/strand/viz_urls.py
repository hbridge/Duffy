from django.conf.urls import patterns, url
from strand import viz_views

urlpatterns = patterns('',
	url(r'^neighbors$', viz_views.neighbors),
)