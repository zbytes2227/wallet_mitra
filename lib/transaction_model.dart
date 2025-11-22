class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String? name;
  final DateTime dateTime;
  final String? smsBody;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    this.name,
    required this.dateTime,
    this.smsBody,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'name': name,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'smsBody': smsBody,
    };
  }

  // FIXED: Handle both int and double for amount
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      amount: (json['amount'] is int) 
          ? (json['amount'] as int).toDouble()  // Convert int to double
          : json['amount'] as double,            // Already double
      type: json['type'],
      name: json['name'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dateTime']),
      smsBody: json['smsBody'],
    );
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? type,
    String? name,
    DateTime? dateTime,
    String? smsBody,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      smsBody: smsBody ?? this.smsBody,
    );
  }
}
