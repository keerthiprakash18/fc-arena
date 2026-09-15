from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import OTPCode
from .serializers import (
    ForgotPasswordSerializer,
    RegisterSerializer,
    ResendOTPSerializer,
    ResetPasswordSerializer,
    UserSerializer,
    VerifyOTPSerializer,
)
from .services import deliver_otp, generate_otp, verify_otp

User = get_user_model()


def _find_user(identifier):
    """Resolve a username *or* email address to a user, case-insensitively."""
    identifier = (identifier or '').strip()
    if not identifier:
        return None
    return (
        User.objects.filter(username__iexact=identifier).first()
        or User.objects.filter(email__iexact=identifier).first()
    )


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        otp_required = getattr(serializer, 'otp_required', False)
        payload = {
            'user_id': user.id,
            'username': user.username,
            'otp_required': otp_required,
            'detail': (
                'Account created. Enter the verification code we sent you to '
                'activate it.'
                if otp_required else
                'Account created. You can sign in now.'
            ),
        }
        code = getattr(serializer, 'otp_debug_code', None)
        if code:
            # No mail transport is configured; hand the code back so the flow is
            # completable. Never populated once SMTP is configured.
            payload['dev_otp'] = code
        return Response(payload, status=status.HTTP_201_CREATED)


class VerifyOTPView(APIView):
    """Activate an account with the code issued at registration."""

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = _find_user(serializer.validated_data['username'])
        if user is None:
            return Response({'detail': 'Incorrect code.'}, status=status.HTTP_400_BAD_REQUEST)

        ok, message = verify_otp(
            user, serializer.validated_data['code'], OTPCode.Purpose.EMAIL_VERIFY
        )
        if not ok:
            return Response({'detail': message}, status=status.HTTP_400_BAD_REQUEST)

        if not user.is_active:
            user.is_active = True
            user.save(update_fields=['is_active'])

        return Response({
            'detail': 'Your account is verified. You can sign in now.',
            'verified': True,
            'username': user.username,
        })


class ResendOTPView(APIView):
    """Issue a replacement code when the first one expired or never arrived."""

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ResendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = _find_user(serializer.validated_data['username'])
        purpose = serializer.validated_data['purpose']

        if user is None:
            # Do not confirm whether the account exists.
            return Response({'detail': 'If that account exists, a new code has been sent.'})

        if purpose == OTPCode.Purpose.EMAIL_VERIFY and user.is_active:
            return Response(
                {'detail': 'This account is already verified. Please sign in.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp = generate_otp(user, purpose)
        code = deliver_otp(user, otp)
        payload = {'detail': 'A new verification code has been sent.'}
        if code:
            payload['dev_otp'] = code
        return Response(payload)


class ForgotPasswordView(APIView):
    """Start a password reset. Always succeeds, to avoid leaking which accounts exist."""

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = _find_user(serializer.validated_data['identifier'])

        payload = {'detail': 'If that account exists, a reset code has been sent.'}
        if user is not None and user.is_active:
            otp = generate_otp(user, OTPCode.Purpose.PASSWORD_RESET)
            code = deliver_otp(user, otp)
            if code:
                payload['dev_otp'] = code
        return Response(payload)


class ResetPasswordView(APIView):
    """Complete a password reset with the emailed code."""

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = _find_user(serializer.validated_data['identifier'])
        if user is None:
            return Response(
                {'detail': 'Invalid or expired reset code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ok, message = verify_otp(
            user, serializer.validated_data['code'], OTPCode.Purpose.PASSWORD_RESET
        )
        if not ok:
            return Response({'detail': message}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password'])
        return Response({'detail': 'Your password has been reset. You can sign in now.'})


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
