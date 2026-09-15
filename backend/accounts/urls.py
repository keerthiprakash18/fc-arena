from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .serializers import FCOTPTokenObtainPairSerializer
from .views import (
    ForgotPasswordView,
    ProfileView,
    RegisterView,
    ResendOTPView,
    ResetPasswordView,
    VerifyOTPView,
)


class LoginView(TokenObtainPairView):
    """Login that distinguishes an unverified account from a bad password."""

    serializer_class = FCOTPTokenObtainPairSerializer


urlpatterns = [
    # Registration is a two-step handshake: create the account, then confirm the
    # one-time code before the account can sign in.
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/verify-otp/', VerifyOTPView.as_view(), name='verify_otp'),
    path('auth/resend-otp/', ResendOTPView.as_view(), name='resend_otp'),

    # Password reset follows the same code-based pattern.
    path('auth/forgot-password/', ForgotPasswordView.as_view(), name='forgot_password'),
    path('auth/reset-password/', ResetPasswordView.as_view(), name='reset_password'),

    path('auth/login/', LoginView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/profile/', ProfileView.as_view(), name='profile'),
]
