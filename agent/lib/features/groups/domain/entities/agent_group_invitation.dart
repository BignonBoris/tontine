class AgentGroupInvitation {
  final String token;
  final String shareUrl;
  final String previewUrl;
  final String invitationType;

  const AgentGroupInvitation({
    required this.token,
    required this.shareUrl,
    required this.previewUrl,
    required this.invitationType,
  });

  factory AgentGroupInvitation.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupInvitation(
      token: '${map['token'] ?? ''}',
      shareUrl: '${map['shareUrl'] ?? ''}',
      previewUrl: '${map['previewUrl'] ?? ''}',
      invitationType: '${map['invitationType'] ?? 'open'}',
    );
  }
}
