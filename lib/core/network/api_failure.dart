import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode, this.details = const {}});

  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  factory ApiFailure.fromDio(DioException exception) {
    final response = exception.response;
    final payload = response?.data;

    if (payload is Map<String, dynamic>) {
      final errors = payload['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            return ApiFailure(
              value.first as String,
              statusCode: response?.statusCode,
              details: payload,
            );
          }
        }
      }

      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ApiFailure(
          message,
          statusCode: response?.statusCode,
          details: payload,
        );
      }
    }

    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout) {
      return const ApiFailure(
        'Travla is taking too long to respond. Check your connection and try again.',
      );
    }

    if (exception.type == DioExceptionType.connectionError) {
      return const ApiFailure(
        'Unable to reach Travla. Check your internet connection and try again.',
      );
    }

    return ApiFailure(
      'Something went wrong. Please try again.',
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
