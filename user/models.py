# users/models.py
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.utils import timezone
from cryptography.fernet import Fernet

class CustomUserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        if not username:
            raise ValueError("The Username field is required")
        if not email:
            raise ValueError("The Email field is required")
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self.create_user(username, email, password, **extra_fields)


class CustomUser(AbstractBaseUser, PermissionsMixin):
    username = models.CharField(max_length=30, unique=True)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=30, blank=True)
    last_name = models.CharField(max_length=30, blank=True)
    profile_picture = models.ImageField(upload_to='profile_pictures/', default="profile_pictures/default-profile-picture.png",  blank=True, null=True)
    date_joined = models.DateTimeField(default=timezone.now)
    country = models.CharField(max_length=50, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_premium = models.BooleanField(default=False)

    objects = CustomUserManager()

    USERNAME_FIELD = "username"
    REQUIRED_FIELDS = ["email"]

    encryption_key = models.CharField(max_length=100, blank=True, null=True)

    def save(self, *args, **kwargs):
        if not self.encryption_key:
            # Generate new key if none exists
            self.encryption_key = Fernet.generate_key().decode()
        super().save(*args, **kwargs)

    def get_fernet(self):
        if not self.encryption_key:
            # generate a key if missing (legacy users)
            self.encryption_key = Fernet.generate_key().decode()
            self.save(update_fields=["encryption_key"])
        return Fernet(self.encryption_key.encode())

    def __str__(self):
        return self.username
