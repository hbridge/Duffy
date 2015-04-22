# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0002_auto_20150421_2233'),
    ]

    operations = [
        migrations.AddField(
            model_name='followup',
            name='for_email',
            field=models.CharField(default='', max_length=1000),
            preserve_default=False,
        ),
    ]
