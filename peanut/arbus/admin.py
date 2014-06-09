from django.contrib import admin
from common.models import Photo, User, Classification, Similarity

# Register your models here.
admin.site.register(Photo)
admin.site.register(User)
admin.site.register(Classification)
admin.site.register(Similarity)