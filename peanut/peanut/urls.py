from django.conf.urls import patterns, include, url
from django.conf import settings

from django.contrib import admin
admin.autodiscover()


urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'peanut.views.home', name='home'),
    # url(r'^blog/', include('blog.urls')),
    url(r'^api/', include('arbus.api_urls')),
    url(r'^viz/', include('arbus.viz_urls')),
    url(r'^admin/', include(admin.site.urls)),
    url(r'^search/', include('haystack.urls')),
    url(r'^strand/api/', include('strand.api_urls')),
    url(r'^strand/viz/', include('strand.viz_urls')),
)

if settings.DEBUG:
    urlpatterns += patterns('',
        (r'^user_data/(?P<path>.*)$', 'django.views.static.serve', {'document_root': '/home/derek/user_data'}),
    )