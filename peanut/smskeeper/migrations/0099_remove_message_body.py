# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0098_merge'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='message',
            name='body',
        ),
    ]
