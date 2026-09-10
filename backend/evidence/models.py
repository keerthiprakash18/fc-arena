import hashlib
from django.db import models
from django.conf import settings


class EvidenceStorage(models.Model):
    match = models.ForeignKey('matches.Match', on_delete=models.CASCADE, related_name='stored_evidence')
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='evidence_uploads')
    file_name = models.CharField(max_length=255)
    file_reference = models.CharField(max_length=500)
    file_size = models.PositiveIntegerField(default=0)
    file_type = models.CharField(max_length=50)
    checksum = models.CharField(max_length=64)
    is_valid = models.BooleanField(default=False)
    validation_errors = models.JSONField(blank=True, default=list)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'evidence_storage'
        ordering = ['-uploaded_at']

    def __str__(self):
        return f"Evidence {self.file_name} for Match {self.match_id}"

    @staticmethod
    def compute_checksum(file_content):
        return hashlib.sha256(file_content).hexdigest()

    def validate(self):
        errors = []
        allowed_types = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
        max_size = 10 * 1024 * 1024

        if self.file_type not in allowed_types:
            errors.append(f"Invalid file type: {self.file_type}. Allowed: {allowed_types}")

        if self.file_size > max_size:
            errors.append(f"File too large: {self.file_size} bytes. Max: {max_size} bytes")

        if self.file_size == 0:
            errors.append("File is empty")

        self.validation_errors = errors
        self.is_valid = len(errors) == 0
        self.save(update_fields=['is_valid', 'validation_errors'])
        return self.is_valid