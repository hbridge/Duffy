from django.contrib import admin
from common.models import Photo, User, Classification, Similarity, NotificationLog, Strand, StrandNeighbor, Action
from django.contrib.admin.actions import delete_selected as delete_selected_

# Register your models here.
admin.site.register(Classification)
admin.site.register(Similarity)
admin.site.register(NotificationLog)

class ActionAdmin(admin.ModelAdmin):
	list_display = ['id', 'action_type', 'added']
admin.site.register(Action, ActionAdmin)

class UserAdmin(admin.ModelAdmin):
	list_display = ['id', 'display_name', 'phone_number', 'photos_info', 'private_strands', 'shared_strands']
admin.site.register(User, UserAdmin)

class PhotoAdmin(admin.ModelAdmin):
	readonly_fields = ['photo_html']
admin.site.register(Photo, PhotoAdmin)

class StrandAdmin(admin.ModelAdmin):
	readonly_fields = ('users_link', 'photos_link')
	exclude = ('photos', 'users')
	list_display = ['id', 'sharing_info', 'user_info', 'photo_info', 'first_photo_time', 'last_photo_time', 'added', 'updated']
admin.site.register(Strand, StrandAdmin)


class StrandNeighborAdmin(admin.ModelAdmin):
	list_display = ['id', 'strand_1', 'strand_2']
admin.site.register(StrandNeighbor, StrandNeighborAdmin)
