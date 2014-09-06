from django.contrib import admin
from common.models import Photo, User, Classification, Similarity, Neighbor, NotificationLog, PhotoAction, Strand

# Register your models here.
admin.site.register(User)
admin.site.register(Classification)
admin.site.register(Similarity)
admin.site.register(Neighbor)
admin.site.register(NotificationLog)
admin.site.register(PhotoAction)


class PhotoAdmin(admin.ModelAdmin):
	readonly_fields = ['photo_html']
admin.site.register(Photo, PhotoAdmin)

class StrandAdmin(admin.ModelAdmin):
	readonly_fields = ('users_link', 'photos_link')
	exclude = ('photos', 'users')
	list_display = ['id', 'sharing_info', 'user_info', 'photo_info', 'first_photo_time', 'last_photo_time', 'added', 'updated']

admin.site.register(Strand, StrandAdmin)