from rest_framework import serializers
from .models import Dispute, DisputeComment


class DisputeCommentSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = DisputeComment
        fields = ['id', 'dispute', 'user', 'username', 'comment', 'created_at']
        read_only_fields = ['id', 'dispute', 'user', 'created_at']


class DisputeSerializer(serializers.ModelSerializer):
    raised_by_name = serializers.CharField(source='raised_by.username', read_only=True)
    resolved_by_name = serializers.CharField(source='resolved_by.username', read_only=True, default=None)
    comments = DisputeCommentSerializer(many=True, read_only=True)

    class Meta:
        model = Dispute
        fields = ['id', 'league', 'match', 'raised_by', 'raised_by_name',
                  'reason', 'description', 'status', 'resolution',
                  'resolved_by', 'resolved_by_name', 'resolution_notes',
                  'comments', 'created_at', 'updated_at']
        read_only_fields = ['id', 'raised_by', 'status', 'resolution',
                           'resolved_by', 'created_at', 'updated_at']


class DisputeCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Dispute
        fields = ['match', 'reason', 'description']

    def validate_match(self, match):
        league = self.context['league']
        if match.league_id != league.id:
            raise serializers.ValidationError("Match does not belong to this league.")
        return match

    def validate(self, attrs):
        league = self.context['league']
        user = self.context['request'].user
        match = attrs.get('match')
        if not match:
            raise serializers.ValidationError("Match is required.")
        if match.home_user != user and match.away_user != user:
            raise serializers.ValidationError(
                "Only participants of the match can raise a dispute."
            )
        if Dispute.objects.filter(match=match, league=league, status='OPEN').exists():
            raise serializers.ValidationError("An open dispute already exists for this match.")
        return attrs


class DisputeResolutionSerializer(serializers.Serializer):
    resolution = serializers.ChoiceField(choices=Dispute.RESOLUTION_CHOICES)
    resolution_notes = serializers.CharField(required=False, default='', allow_blank=True)