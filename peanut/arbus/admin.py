from django.contrib import admin
from common.models import Photo, User, Classification, Similarity, Neighbor, NotificationLog, PhotoAction, Strand

# Register your models here.
admin.site.register(Photo)
admin.site.register(User)
admin.site.register(Classification)
admin.site.register(Similarity)
admin.site.register(Neighbor)
admin.site.register(NotificationLog)
admin.site.register(PhotoAction)
admin.site.register(Strand)