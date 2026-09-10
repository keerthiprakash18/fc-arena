from rest_framework import serializers
from .models import AuditLog


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.username', read_only=True, default=None)

    class Meta:
        model = AuditLog
        fields = ['id', 'actor', 'actor_name', 'action', 'entity_type',
                  'entity_id', 'league', 'timestamp', 'before', 'after',
                  'metadata', 'ip_address']
        read_only_fields = ['id', 'timestamp']