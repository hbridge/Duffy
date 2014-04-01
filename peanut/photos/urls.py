from django.conf.urls import patterns, url
from photos import views

urlpatterns = patterns('',
    url(r'^addPhoto$', views.addPhoto, name='addPhoto'),
    url(r'^manualAddPhoto$', views.manualAddPhoto, name='manualAddPhoto'),
    url(r'^groups/(?P<user_id>\d+)/$', views.groups, name='groups'),
)