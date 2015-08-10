# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0074_user_temp_format'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='temp_format',
            field=models.CharField(default=b'imperial', max_length=10, choices=[(b'imperial', b'imperial'), (b'metric', b'metric')]),
        ),
    ]
