# middleware/block_progress_images.py
import re
from django.http import HttpResponseForbidden

class BlockDirectProgressImageAccessMiddleware:
    """
    Blocks direct access to /media/progress_images/ files.
    Forces users to go through the protected view instead.
    """
    def __init__(self, get_response):
        self.get_response = get_response
        self.block_pattern = re.compile(r"^/media/progress_images/")
        self.allow_patterns = [
            re.compile(r"^/media/protected/"),   # allow protected view
            re.compile(r"^/api/progress/"),      # allow API progress endpoints
        ]

    def __call__(self, request):
        path = request.path

        # If path matches allowlist → skip blocking
        for pattern in self.allow_patterns:
            if pattern.match(path):
                return self.get_response(request)

        # Block direct access to progress_images directory
        if self.block_pattern.match(path):
            return HttpResponseForbidden("Direct access to progress images is not allowed.")

        return self.get_response(request)
