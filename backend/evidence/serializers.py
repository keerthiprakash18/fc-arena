from rest_framework import serializers
from .models import EvidenceStorage


class EvidenceStorageSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.username', read_only=True)

    class Meta:
        model = EvidenceStorage
        fields = ['id', 'match', 'uploaded_by', 'uploaded_by_name',
                  'file_name', 'file_reference', 'file_size', 'file_type',
                  'checksum', 'is_valid', 'validation_errors', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_by', 'checksum', 'is_valid',
                           'validation_errors', 'uploaded_at']


class EvidenceUploadSerializer(serializers.Serializer):
    file_name = serializers.CharField(max_length=255)
    file_size = serializers.IntegerField()
    file_type = serializers.CharField(max_length=50)
    file_content_base64 = serializers.CharField()

    def validate_file_size(self, value):
        max_size = 10 * 1024 * 1024
        if value > max_size:
            raise serializers.ValidationError(f"File too large. Max: {max_size} bytes")
        if value == 0:
            raise serializers.ValidationError("File is empty")
        return value

    def validate_file_type(self, value):
        allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
        if value not in allowed:
            raise serializers.ValidationError(f"Invalid file type. Allowed: {allowed}")
        return value