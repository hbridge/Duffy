from django.conf.urls import patterns, url
from strand import viz_views

urlpatterns = patterns('',
	url(r'^strandStats$', viz_views.strandStats),
	url(r'^neighbors$', viz_views.neighbors),
	url(r'^images$', viz_views.serveImage),
	url(r'^report_inappropriate', viz_views.innapropriateContentForm),
)