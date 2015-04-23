# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Note',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('label', models.CharField(max_length=100)),
                ('text', models.TextField(null=True)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='User',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('phone_number', models.CharField(unique=True, max_length=100)),
                ('name', models.CharField(max_length=100)),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
                ('updated', models.DateTimeField(db_index=True, auto_now=True, null=True)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.AddField(
            model_name='note',
            name='user',
            field=models.ForeignKey(to='smskeeper.User'),
            preserve_default=True,
        ),
    ]
