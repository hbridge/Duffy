# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0013_remove_user_activated'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='activated',
            field=models.DateTimeField(null=True),
            preserve_default=True,
        ),
    ]
