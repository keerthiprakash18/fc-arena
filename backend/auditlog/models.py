from django.db import models
from django.conf import settings


class AuditLog(models.Model):
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='audit_actions')
    action = models.CharField(max_length=100)
    entity_type = models.CharField(max_length=100)
    entity_id = models.CharField(max_length=100)
    league = models.ForeignKey('leagues.League', on_delete=models.SET_NULL, null=True, blank=True, related_name='audit_logs')
    timestamp = models.DateTimeField(auto_now_add=True)
    before = models.JSONField(blank=True, default=dict)
    after = models.JSONField(blank=True, default=dict)
    metadata = models.JSONField(blank=True, default=dict)
    ip_address = models.GenericIPAddressField(blank=True, null=True)

    class Meta:
        db_table = 'audit_logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f"[{self.timestamp}] {self.actor} - {self.action} {self.entity_type}#{self.entity_id}"

    @classmethod
    def log(cls, actor, action, entity_type, entity_id,
            league=None, before=None, after=None, metadata=None, ip_address=None):
        return cls.objects.create(
            actor=actor,
            action=action,
            entity_type=entity_type,
            entity_id=str(entity_id),
            league=league,
            before=before or {},
            after=after or {},
            metadata=metadata or {},
            ip_address=ip_address,
        )