# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0075_auto_20150810_2136'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='signature_num_lines',
            field=models.IntegerField(null=True),
            preserve_default=True,
        ),
    ]
