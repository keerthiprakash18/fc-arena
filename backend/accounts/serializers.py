from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import OTPCode
from .services import deliver_otp, generate_otp

User = get_user_model()

# The exact wording the client matches on to route an unverified user back to
# the OTP screen. Kept as a constant so the two sides cannot drift apart.
ACCOUNT_NOT_VERIFIED_MESSAGE = (
    'Your account has not been verified yet. Enter the code we sent you, '
    'or request a new one.'
)


class UserSerializer(serializers.ModelSerializer):
    isStaff = serializers.BooleanField(source='is_staff', read_only=True)
    isSuperuser = serializers.BooleanField(source='is_superuser', read_only=True)
    dateJoined = serializers.DateTimeField(source='date_joined', read_only=True)
    display_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name',
                  'game_uid', 'game_in_game_name', 'phone_number',
                  'profile_photo', 'date_of_birth',
                  # These three are real User model fields that were being
                  # silently dropped from the API payload.
                  'position', 'country', 'social_links',
                  'display_name',
                  'isStaff', 'isSuperuser', 'dateJoined']
        read_only_fields = ['id', 'isStaff', 'isSuperuser', 'dateJoined']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'first_name', 'last_name',
                  'game_uid', 'game_in_game_name', 'phone_number']

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)

        # When OTP verification is switched on the account starts inactive and
        # only becomes usable after the emailed code is confirmed. The code (if
        # the caller is allowed to see it) is stashed on the serializer so the
        # view can surface it during local development.
        self.otp_debug_code = None
        self.otp_required = False
        if getattr(settings, 'REQUIRE_OTP_VERIFICATION', True):
            user.is_active = False
            user.save(update_fields=['is_active'])
            otp = generate_otp(user, OTPCode.Purpose.EMAIL_VERIFY)
            self.otp_debug_code = deliver_otp(user, otp)
            self.otp_required = True
        return user


class VerifyOTPSerializer(serializers.Serializer):
    """Confirm the code that was issued for a freshly registered account."""

    username = serializers.CharField(help_text='Username or email address.')
    code = serializers.CharField(max_length=6)


class ResendOTPSerializer(serializers.Serializer):
    username = serializers.CharField(help_text='Username or email address.')
    purpose = serializers.ChoiceField(
        choices=OTPCode.Purpose.choices,
        default=OTPCode.Purpose.EMAIL_VERIFY,
    )


class ForgotPasswordSerializer(serializers.Serializer):
    identifier = serializers.CharField(help_text='Username or email address.')


class ResetPasswordSerializer(serializers.Serializer):
    identifier = serializers.CharField(help_text='Username or email address.')
    code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(min_length=8, write_only=True)


class FCOTPTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Login that tells an unverified user *why* they cannot get in.

    Django's auth backend rejects inactive users, so a plain login would report
    every unverified account as "no active account", which reads exactly like a
    wrong password. We only reveal the real reason when the supplied password is
    correct, so this cannot be used to enumerate usernames.
    """

    def validate(self, attrs):
        username = attrs.get(self.username_field)
        password = attrs.get('password')
        if username and password:
            candidate = User.objects.filter(username=username).first()
            if (
                candidate is not None
                and not candidate.is_active
                and candidate.check_password(password)
            ):
                raise AuthenticationFailed(ACCOUNT_NOT_VERIFIED_MESSAGE)
        return super().validate(attrs)
