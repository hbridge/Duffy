from django.contrib import admin
from photos.models import Photo, User, Classification

# Register your models here.
admin.site.register(Photo)
admin.site.register(User)
admin.site.register(Classification)