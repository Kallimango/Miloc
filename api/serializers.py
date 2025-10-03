# progress_tracking/serializers.py
# api/serializers.py
from rest_framework import serializers
from progress_tracking.models import ProgressImage, Category
from rest_framework import serializers
from user.models import CustomUser
from django.contrib.auth.password_validation import validate_password
import base64
from io import BytesIO
from django.core.files.base import ContentFile

class RegisterSerializer(serializers.ModelSerializer):
    profile_picture = serializers.ImageField(required=False)

    class Meta:
        model = CustomUser
        fields = ['username', 'email', 'first_name', 'last_name', 'country', 'password', 'password2', 'profile_picture']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        password = validated_data.pop('password')
        password2 = validated_data.pop('password2')

        if password != password2:
            raise serializers.ValidationError("Passwords do not match")

        profile_picture = validated_data.pop('profile_picture', None)

        # Handle base64 image for web
        if isinstance(profile_picture, str):  # base64 string received
            decoded_image = base64.b64decode(profile_picture)
            profile_picture = ContentFile(decoded_image, name='profile_picture.jpg')

        user = CustomUser(**validated_data)
        user.set_password(password)
        if profile_picture:
            user.profile_picture = profile_picture
        user.save()
        return user




class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ["id", "name"]


class ProgressImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgressImage
        fields = ['id', 'image', 'category', 'date']
        read_only_fields = ['id', 'date', 'category']  # category now read-only

    def validate_image(self, value):
        if not value.content_type.startswith('image/'):
            raise serializers.ValidationError("Only image files are allowed.")
        return value