/// Expense model — maps to `expenses` table in Supabase
class Expense {
  final String id;
  final String workOrderId;
  final String? propertyId;
  final double amount;
  final String? description;
  final String? category; // material, labor, contractor, etc.
  final String? receiptUrl;
  final bool billableToPartner;
  final DateTime expenseDate;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.workOrderId,
    this.propertyId,
    required this.amount,
    this.description,
    this.category,
    this.receiptUrl,
    this.billableToPartner = false,
    required this.expenseDate,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      workOrderId: json['work_order_id'] as String,
      propertyId: json['property_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      category: json['category'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      billableToPartner: json['billable_to_partner'] as bool? ?? false,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'work_order_id': workOrderId,
    'property_id': propertyId,
    'amount': amount,
    'description': description,
    'category': category,
    'receipt_url': receiptUrl,
    'billable_to_partner': billableToPartner,
    'expense_date': expenseDate.toIso8601String(),
  };
}
