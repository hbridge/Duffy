# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0006_auto_20150422_1537'),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name='contactentry',
            unique_together=set([('user', 'email')]),
        ),
    ]
