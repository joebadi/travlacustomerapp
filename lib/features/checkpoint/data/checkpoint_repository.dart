import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/checkpoint/domain/checkpoint_models.dart';

class CheckpointRepository {
  CheckpointRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CheckpointState> load(String vehicleId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/checkpoint',
      );
      return CheckpointState.fromJson(_data(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<CheckpointPreview> preview(String vehicleId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/checkpoint/preview',
      );
      return CheckpointPreview.fromJson(_data(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<CheckpointState> enable(String vehicleId) =>
      _mutate('/vehicles/$vehicleId/checkpoint');

  Future<CheckpointState> rotate(String vehicleId) =>
      _mutate('/vehicles/$vehicleId/checkpoint/rotate');

  Future<void> disable(String vehicleId) async {
    try {
      await _apiClient.dio.delete<void>('/vehicles/$vehicleId/checkpoint');
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<File> download(String vehicleId, {required bool compact}) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/travla-checkpoint-${compact ? 'compact' : 'a4'}-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    try {
      await _apiClient.dio.download(
        '/vehicles/$vehicleId/checkpoint/print',
        file.path,
        queryParameters: {'format': compact ? 'compact' : 'a4'},
        options: Options(headers: const {'Accept': 'application/pdf'}),
      );
      return file;
    } on DioException catch (exception) {
      if (await file.exists()) await file.delete();
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<CheckpointState> _mutate(String path) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(path);
      return CheckpointState.fromJson(_data(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is! Map) {
      throw const ApiFailure(
        'Travla returned an unexpected Checkpoint record.',
      );
    }
    return Map<String, dynamic>.from(data);
  }
}

final checkpointRepositoryProvider = Provider<CheckpointRepository>((ref) {
  return CheckpointRepository(ref.watch(apiClientProvider));
});

final checkpointProvider = FutureProvider.autoDispose
    .family<CheckpointState, String>((ref, vehicleId) {
      return ref.watch(checkpointRepositoryProvider).load(vehicleId);
    });
