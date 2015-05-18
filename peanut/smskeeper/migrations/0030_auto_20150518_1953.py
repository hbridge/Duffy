# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0029_auto_20150518_1724'),
    ]

    operations = [
        migrations.AlterField(
            model_name='entry',
            name='img_url',
            field=models.TextField(null=True, blank=True),
        ),
    ]
