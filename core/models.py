from django.db import models
from user.models import *
from django.conf import settings

# Create your models here.

class FeedbackMessage(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="feedback_message"
    )
    body = models.CharField(max_length=500, blank=False)
    def __str__(self):
        return f"Feedback from {self.user}"