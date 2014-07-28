from random import randint
import datetime

from rest_framework.generics import CreateAPIView, GenericAPIView
from rest_framework.response import Response
from rest_framework.mixins import CreateModelMixin
from rest_framework import status

from common.models import PhotoAction, ContactEntry


class BulkCreateModelMixin(CreateModelMixin):
    """
    Either create a single or many model instances in bulk by using the
    Serializer's ``many=True`` ability from Django REST >= 2.2.5.

    .. note::
        This mixin uses the same method to create model instances
        as ``CreateModelMixin`` because both non-bulk and bulk
        requests will use ``POST`` request method.

    Pulled from: https://github.com/miki725/django-rest-framework-bulk
    """

    def create(self, request, *args, **kwargs):
        bulk = isinstance(request.DATA, list)

        if not bulk:
            return super(BulkCreateModelMixin, self).create(request, *args, **kwargs)

        else:
            serializer = self.get_serializer(data=request.DATA, many=True)
            model = serializer.opts.model
            if serializer.is_valid():
                [self.pre_save(obj) for obj in serializer.object]

                batchKey = randint(1,10000)
                for obj in serializer.object:
                    obj.bulk_batch_key = batchKey

                self.object = model.objects.bulk_create(serializer.object)

                # Only want to grab stuff from the last 10 seconds since bulk_batch_key could repeat
                dt = datetime.datetime.now() - datetime.timedelta(seconds=10)
                serializer.object = model.objects.filter(bulk_batch_key = batchKey).filter(added__gt=dt)

                [self.post_save(obj, created=True) for obj in serializer.object]
                return Response(serializer.data, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

"""
    Used to do a fast bulk update with one write to the database
"""
class BulkCreateAPIView(BulkCreateModelMixin,
                        GenericAPIView):
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)

"""
    REST interface for creating new PhotoActions.

    Use a custom overload of the create method so we don't double create likes
"""
class CreatePhotoActionAPI(CreateAPIView):
    def post(self, request):
        serializer = self.get_serializer(data=request.DATA, files=request.FILES)

        if serializer.is_valid():
            obj = serializer.object
            results = PhotoAction.objects.filter(photo_id=obj.photo_id, user_id=obj.user_id, action_type=obj.action_type)

            if len(results) > 0:
                serializer = self.get_serializer(results[0])
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return super(CreatePhotoActionAPI, self).post(request)
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
