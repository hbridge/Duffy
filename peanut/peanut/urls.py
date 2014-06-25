from django.conf.urls import patterns, include, url
from django.conf import settings

from django.contrib import admin
admin.autodiscover()

from peanut.settings import constants

urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'peanut.views.home', name='home'),
    # url(r'^blog/', include('blog.urls')),
    url(r'^admin/', include(admin.site.urls)),

    url(r'^api/', include('arbus.api_urls')),
    url(r'^viz/', include('arbus.viz_urls')),
    
    url(r'^strand/api/', include('strand.api_urls')),
    url(r'^strand/viz/', include('strand.viz_urls')),
    
    url(r'^ios-notifications/', include('ios_notifications.urls')),
)

if settings.DEBUG:
    urlpatterns += patterns('',
        (r'^user_data/(?P<path>.*)$', 'django.views.static.serve', {'document_root': constants.PIPELINE_LOCAL_BASE_PATH}),
    )