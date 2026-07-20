import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/order_model.dart';

class ChatScreen extends StatefulWidget {
  final OrderModel order;
  const ChatScreen({super.key, required this.order});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isSending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      final orderRef = _db.collection('orders').doc(widget.order.orderId);
      final orderSnapshot = await orderRef.get();
      if (!mounted) return;

      final orderData = orderSnapshot.data() ?? <String, dynamic>{};
      final customerId = (orderData['customerId'] as String?)?.trim().isNotEmpty == true
          ? (orderData['customerId'] as String).trim()
          : widget.order.customerId;
      final partnerId = (orderData['partnerId'] as String?)?.trim().isNotEmpty == true
          ? (orderData['partnerId'] as String).trim()
          : (widget.order.partnerId ?? user.uid);

      if (customerId.isEmpty) {
        AppTheme.showSnack(context, 'Customer is not available for chat.', isError: true);
        return;
      }
      if (user.uid != partnerId && widget.order.partnerId != null && widget.order.partnerId!.isNotEmpty) {
        AppTheme.showSnack(context, 'You do not have access to this chat.', isError: true);
        return;
      }

      final msgRef = orderRef.collection('messages').doc();
      final clientTimestamp = Timestamp.now();
      final senderName = (orderData['partnerName'] as String?)?.trim().isNotEmpty == true
          ? (orderData['partnerName'] as String).trim()
          : (widget.order.partnerName ?? 'Partner');

      final messageData = {
        'id': msgRef.id,
        'clientMessageId': msgRef.id,
        'orderId': widget.order.orderId,
        'customerId': customerId,
        'partnerId': partnerId,
        'senderId': user.uid,
        'fromId': user.uid,
        'senderName': senderName,
        'senderRole': 'partner',
        'recipientId': customerId,
        'receiverId': customerId,
        'toId': customerId,
        'recipientRole': 'customer',
        'receiverRole': 'customer',
        'text': text,
        'message': text,
        'body': text,
        'type': 'chat',
        'isRead': false,
        'timestamp': clientTimestamp,
      };

      final batch = _db.batch();
      batch.set(msgRef, {
        ...messageData,
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestamp': clientTimestamp,
      });
      batch.update(orderRef, {
        'notification': FieldValue.arrayUnion([messageData]),
        'lastChatMessage': text,
        'lastChatSenderId': user.uid,
        'lastChatRecipientId': customerId,
        'lastChatMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        ...messageData,
        'notificationId': notifRef.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _messageCtrl.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        AppTheme.showSnack(context, 'Failed to send message. Try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  List<_ChatMessage> _messagesFromOrderData(Map<String, dynamic> orderData, String currentUid) {
    final rawMessages = <dynamic>[
      ..._asMessageList(orderData['notification']),
      ..._asMessageList(orderData['notifications']),
    ];
    final customerId = orderData['customerId'] as String? ?? widget.order.customerId;
    final partnerId = orderData['partnerId'] as String? ?? widget.order.partnerId ?? currentUid;

    final messages = <_ChatMessage>[];
    for (var i = 0; i < rawMessages.length; i++) {
      final raw = rawMessages[i];
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final message = _ChatMessage.fromMap(data, fallbackId: 'order-$i');
      if (message.text.isEmpty) continue;
      if (!_isVisibleChatMessage(message, data, currentUid, customerId, partnerId)) continue;
      messages.add(message);
    }
    return messages;
  }

  List<dynamic> _asMessageList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      if (raw.containsKey('text') || raw.containsKey('message') || raw.containsKey('body')) {
        return [raw];
      }
      return raw.values.toList();
    }
    return const [];
  }

  bool _isVisibleChatMessage(
    _ChatMessage message,
    Map<String, dynamic> data,
    String currentUid,
    String customerId,
    String partnerId,
  ) {
    final type = (data['type'] ?? data['notificationType'] ?? '').toString().toLowerCase();
    final senderRole = (data['senderRole'] ?? data['role'] ?? '').toString().toLowerCase();
    final recipientRole = (data['recipientRole'] ?? data['receiverRole'] ?? '').toString().toLowerCase();
    final looksLikeChat = type.isEmpty ||
        type == 'chat' ||
        type == 'message' ||
        senderRole == 'customer' ||
        senderRole == 'partner' ||
        recipientRole == 'customer' ||
        recipientRole == 'partner';
    if (!looksLikeChat) return false;

    if (message.recipientId.isNotEmpty &&
        message.senderId != currentUid &&
        message.recipientId != currentUid) {
      return false;
    }

    final allowedIds = {
      if (currentUid.isNotEmpty) currentUid,
      if (customerId.isNotEmpty) customerId,
      if (partnerId.isNotEmpty) partnerId,
    };
    return message.senderId.isEmpty ||
        allowedIds.contains(message.senderId) ||
        allowedIds.contains(message.recipientId);
  }

  List<_ChatMessage> _mergeMessages(
    List<_ChatMessage> orderMessages,
    List<QueryDocumentSnapshot> collectionDocs,
    String currentUid,
    Map<String, dynamic> orderData,
  ) {
    final customerId = orderData['customerId'] as String? ?? widget.order.customerId;
    final partnerId = orderData['partnerId'] as String? ?? widget.order.partnerId ?? currentUid;
    final messages = <_ChatMessage>[...orderMessages];
    final seenIds = orderMessages
        .map((message) => message.clientMessageId.isNotEmpty ? message.clientMessageId : message.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final doc in collectionDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final message = _ChatMessage.fromMap(data, fallbackId: doc.id);
      if (message.text.isEmpty) continue;
      if (!_isVisibleChatMessage(message, data, currentUid, customerId, partnerId)) continue;
      final stableId = message.clientMessageId.isNotEmpty ? message.clientMessageId : message.id;
      if (stableId.isNotEmpty && seenIds.contains(stableId)) continue;
      if (_hasNearDuplicate(messages, message)) continue;
      messages.add(message);
      if (stableId.isNotEmpty) seenIds.add(stableId);
    }

    messages.sort((a, b) {
      final aTime = a.timestamp?.millisecondsSinceEpoch ?? 1 << 62;
      final bTime = b.timestamp?.millisecondsSinceEpoch ?? 1 << 62;
      return aTime.compareTo(bTime);
    });
    return messages;
  }

  bool _hasNearDuplicate(List<_ChatMessage> messages, _ChatMessage candidate) {
    for (final existing in messages) {
      if (existing.senderId != candidate.senderId || existing.text != candidate.text) continue;
      final existingTime = existing.timestamp;
      final candidateTime = candidate.timestamp;
      if (existingTime == null || candidateTime == null) return true;
      final delta = existingTime.millisecondsSinceEpoch - candidateTime.millisecondsSinceEpoch;
      if (delta.abs() < 5000) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid ?? '';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                widget.order.customerName.isNotEmpty ? widget.order.customerName[0].toUpperCase() : 'C',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.customerName.isNotEmpty ? widget.order.customerName : 'Customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  Text(
                    widget.order.areaName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.primaryLight,
                  child: Text(
                    '${isHindi ? "Order ID" : "Order ID"}: #${_shortOrderId(widget.order.orderId)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _db.collection('orders').doc(widget.order.orderId).snapshots(),
                    builder: (context, orderSnapshot) {
                      final orderData = orderSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                      final orderMessages = _messagesFromOrderData(orderData, currentUid);

                      return StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('orders')
                            .doc(widget.order.orderId)
                            .collection('messages')
                            .orderBy('timestamp', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError || orderSnapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Failed to load messages',
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
                              ),
                            );
                          }

                          if ((snapshot.connectionState == ConnectionState.waiting ||
                                  orderSnapshot.connectionState == ConnectionState.waiting) &&
                              !snapshot.hasData &&
                              orderMessages.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                          }

                          final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
                          final messages = _mergeMessages(orderMessages, docs, currentUid, orderData);
                          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textHint.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      isHindi ? 'Start conversation with customer' : 'Start conversation with customer',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final bubbleMaxWidth = (constraints.maxWidth * 0.78).clamp(220.0, 520.0);
                              final horizontalPadding = constraints.maxWidth < 420 ? 12.0 : 16.0;

                              return ListView.builder(
                                controller: _scrollCtrl,
                                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMe = message.senderId == currentUid || message.senderRole == 'partner';
                                  return _buildMessageBubble(
                                    message.text,
                                    isMe,
                                    _formatTime(message.timestamp),
                                    bubbleMaxWidth,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildInputBar(isHindi),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortOrderId(String orderId) {
    if (orderId.length <= 6) return orderId.toUpperCase();
    return orderId.substring(orderId.length - 6).toUpperCase();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageBubble(String text, bool isMe, String time, double maxWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
            boxShadow: AppTheme.subtleShadow,
            border: isMe ? null : Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isHindi) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _messageCtrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: isHindi ? 'Type message...' : 'Type message...',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSending ? AppTheme.primary.withOpacity(0.7) : AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final String clientMessageId;
  final String senderId;
  final String senderRole;
  final String recipientId;
  final String text;
  final Timestamp? timestamp;

  const _ChatMessage({
    required this.id,
    required this.clientMessageId,
    required this.senderId,
    required this.senderRole,
    required this.recipientId,
    required this.text,
    required this.timestamp,
  });

  factory _ChatMessage.fromMap(Map<String, dynamic> data, {required String fallbackId}) {
    return _ChatMessage(
      id: (data['id'] ?? fallbackId).toString(),
      clientMessageId: (data['clientMessageId'] ?? '').toString(),
      senderId: (data['senderId'] ?? data['sender_id'] ?? data['fromId'] ?? data['from_id'] ?? data['from'] ?? '').toString(),
      senderRole: (data['senderRole'] ?? data['role'] ?? '').toString(),
      recipientId: (data['recipientId'] ?? data['recipient_id'] ?? data['receiverId'] ?? data['receiver_id'] ?? data['toId'] ?? data['to_id'] ?? data['to'] ?? '').toString(),
      text: (data['text'] ?? data['message'] ?? data['body'] ?? '').toString().trim(),
      timestamp: _readTimestamp(data['timestamp'] ?? data['createdAt'] ?? data['created_at'] ?? data['clientTimestamp']),
    );
  }

  static Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }
}
