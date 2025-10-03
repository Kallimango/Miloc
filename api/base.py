from rest_framework.views import APIView
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt

# Base class for CSRF-exempt API views (safe for JWT)
@method_decorator(csrf_exempt, name='dispatch')
class CsrfExemptAPIView(APIView):
    pass