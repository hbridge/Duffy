# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0049_messageclassification'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='messageclassification',
            name='message',
        ),
        migrations.DeleteModel(
            name='MessageClassification',
        ),
        migrations.AddField(
            model_name='message',
            name='classification',
            field=models.CharField(db_index=True, max_length=100, null=True, blank=True),
            preserve_default=True,
        ),
    ]
