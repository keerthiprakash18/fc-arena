from django.db import models
from django.conf import settings


class VerificationTask(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('AI_PROCESSING', 'AI Processing'),
        ('AI_VERIFIED', 'AI Verified'),
        ('ADMIN_REVIEW', 'Admin Review'),
        ('DISPUTED', 'Disputed'),
        ('REJECTED', 'Rejected'),
        ('VERIFIED', 'Verified'),
    ]

    match = models.OneToOneField('matches.Match', on_delete=models.CASCADE, related_name='verification_task')
    evidence = models.ForeignKey('evidence.EvidenceStorage', on_delete=models.CASCADE, related_name='verification_tasks')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    ai_extracted_data = models.JSONField(blank=True, default=dict)
    ai_confidence_score = models.DecimalField(max_digits=5, decimal_places=4, blank=True, null=True)
    ai_provider = models.CharField(max_length=100, default='placeholder')
    admin_notes = models.TextField(blank=True, default='')
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='admin_verifications')
    verified_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'verification_tasks'
        ordering = ['-created_at']

    def __str__(self):
        return f"Verification for Match {self.match_id} ({self.status})"


class ExtractionResult(models.Model):
    verification_task = models.ForeignKey(VerificationTask, on_delete=models.CASCADE, related_name='extraction_results')
    field_name = models.CharField(max_length=100)
    field_value = models.CharField(max_length=500, blank=True, null=True)
    confidence = models.DecimalField(max_digits=5, decimal_places=4, default=0)
    source_region = models.CharField(max_length=200, blank=True, default='')
    is_reliable = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'extraction_results'
        ordering = ['field_name']

    def __str__(self):
        return f"{self.field_name}: {self.field_value} ({self.confidence})"