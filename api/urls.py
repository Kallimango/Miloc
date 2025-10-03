from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import CreateProgressVideoView, UploadVideoView, ProgressImageCreateView, CategoryViewSet, UserCategoryProgressView, LogoutView, RegisterView, protected_media, ProgressImageViewSet
from django.conf import settings
from django.conf.urls.static import static
from . import views

progress_image_create = ProgressImageViewSet.as_view({
    'post': 'create',   # allow POST for creation
    'get': 'list'       # optionally keep GET for listing
})

urlpatterns = [
    path("feedback/create/", views.create_feedback, name="create_feedback"),
    # Upload generated video (Instagram/TikTok stubs)
    path("progress/video/upload/", UploadVideoView.as_view(), name="progress-video-upload"),
    path("progress/video/create/", CreateProgressVideoView.as_view(), name="progress-video-create"),
    # Auth
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/login/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("auth/logout/", LogoutView.as_view(), name="auth_logout"),

    # Categories
    path("categories/", CategoryViewSet.as_view({"get": "list"}), name="category-list"),

    # Progress
    path("progress/<str:username>/<str:category_name>/", UserCategoryProgressView.as_view(), name="user-category-progress"),
    path("progress/create/", ProgressImageCreateView.as_view(), name="create-progress-image"),
        # Create a video from progress images





    # Protected file streaming (images + videos)
    path("media/protected/<path:file_path>", protected_media, name="protected_media"),

]

