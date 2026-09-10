from rest_framework import serializers
from .models import VerificationTask, ExtractionResult


class ExtractionResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExtractionResult
        fields = ['id', 'verification_task', 'field_name', 'field_value',
                  'confidence', 'source_region', 'is_reliable', 'created_at']
        read_only_fields = ['id', 'created_at']


class VerificationTaskSerializer(serializers.ModelSerializer):
    results = ExtractionResultSerializer(many=True, read_only=True)
    verified_by_name = serializers.CharField(source='verified_by.username', read_only=True, default=None)
    evidence_file = serializers.CharField(source='evidence.file_name', read_only=True)

    class Meta:
        model = VerificationTask
        fields = ['id', 'match', 'evidence', 'evidence_file', 'status',
                  'ai_extracted_data', 'ai_confidence_score', 'ai_provider',
                  'admin_notes', 'verified_by', 'verified_by_name',
                  'verified_at', 'results', 'created_at', 'updated_at']
        read_only_fields = ['id', 'ai_extracted_data', 'ai_confidence_score',
                           'ai_provider', 'verified_by', 'verified_at',
                           'created_at', 'updated_at']


class AdminReviewSerializer(serializers.Serializer):
    approved = serializers.BooleanField()
    notes = serializers.CharField(required=False, default='', allow_blank=True)