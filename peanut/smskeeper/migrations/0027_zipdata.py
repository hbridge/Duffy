# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0026_auto_20150514_1651'),
    ]

    operations = [
        migrations.CreateModel(
            name='ZipData',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('city', models.CharField(max_length=100)),
                ('state', models.CharField(max_length=10)),
                ('zip_code', models.CharField(max_length=10)),
                ('timezone', models.CharField(max_length=10)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
