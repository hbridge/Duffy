# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0002_auto_20150423_1803'),
    ]

    operations = [
        migrations.AddField(
            model_name='incomingmessage',
            name='added',
            field=models.DateTimeField(db_index=True, auto_now_add=True, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='incomingmessage',
            name='updated',
            field=models.DateTimeField(db_index=True, auto_now=True, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='note',
            name='added',
            field=models.DateTimeField(db_index=True, auto_now_add=True, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='note',
            name='updated',
            field=models.DateTimeField(db_index=True, auto_now=True, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='noteentry',
            name='added',
            field=models.DateTimeField(db_index=True, auto_now_add=True, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='noteentry',
            name='updated',
            field=models.DateTimeField(db_index=True, auto_now=True, null=True),
            preserve_default=True,
        ),
    ]
