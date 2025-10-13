import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/capability.dart';
import '../../core/llm_error.dart';
import '../../models/file_models.dart';
import 'client.dart';
import 'config.dart';

/// OpenAI File Management capability implementation
///
/// This module handles file upload, listing, retrieval, and deletion
/// for OpenAI providers.
class OpenAIFiles implements FileManagementCapability {
  final OpenAIClient client;
  final OpenAIConfig config;

  OpenAIFiles(this.client, this.config);

  @override
  Future<FileObject> uploadFile(FileUploadRequest request) async {
    final formData = FormData();

    formData.files.add(
      MapEntry(
        'file',
        MultipartFile.fromBytes(
          request.file,
          filename: request.filename,
        ),
      ),
    );

    if (request.purpose != null) {
      formData.fields.add(MapEntry('purpose', request.purpose!.value));
    }

    final responseData = await client.postForm('files', formData);
    return FileObject.fromOpenAI(responseData);
  }

  @override
  Future<FileListResponse> listFiles([
    FileListQuery? query,
    CancelToken? cancelToken,
  ]) async {
    String endpoint = 'files';

    if (query != null) {
      final queryParams = query.toOpenAIQueryParameters();
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        endpoint = '$endpoint?$queryString';
      }
    }

    final responseData = await client.get(endpoint, cancelToken: cancelToken);
    return FileListResponse.fromOpenAI(responseData);
  }

  @override
  Future<FileObject> retrieveFile(String fileId,
      {CancelToken? cancelToken}) async {
    final responseData =
        await client.get('files/$fileId', cancelToken: cancelToken);
    return FileObject.fromOpenAI(responseData);
  }

  @override
  Future<FileDeleteResponse> deleteFile(String fileId) async {
    final responseData = await client.delete('files/$fileId');
    return FileDeleteResponse.fromOpenAI(responseData);
  }

  @override
  Future<List<int>> getFileContent(String fileId,
      {CancelToken? cancelToken}) async {
    return await client.getRaw('files/$fileId/content',
        cancelToken: cancelToken);
  }

  /// Get file content as string
  Future<String> getFileContentAsString(String fileId,
      {CancelToken? cancelToken}) async {
    final bytes = await getFileContent(fileId, cancelToken: cancelToken);
    return String.fromCharCodes(bytes);
  }

  /// Check if a file exists
  Future<bool> fileExists(String fileId, {CancelToken? cancelToken}) async {
    try {
      await retrieveFile(fileId, cancelToken: cancelToken);
      return true;
    } catch (e) {
      if (e is ResponseFormatError && e.message.contains('404')) {
        return false;
      }
      rethrow;
    }
  }

  /// Get file size in bytes
  Future<int?> getFileSize(String fileId, {CancelToken? cancelToken}) async {
    try {
      final file = await retrieveFile(fileId, cancelToken: cancelToken);
      return file.sizeBytes;
    } catch (e) {
      return null;
    }
  }

  /// List files by purpose
  Future<List<FileObject>> listFilesByPurpose(FilePurpose purpose,
      {CancelToken? cancelToken}) async {
    final response = await listFiles(FileListQuery(purpose: purpose),
        cancelToken: cancelToken);
    return response.data;
  }

  /// Upload file from bytes with automatic filename
  Future<FileObject> uploadFileFromBytes(
    List<int> bytes,
    FilePurpose purpose, {
    String? filename,
  }) async {
    return uploadFile(FileUploadRequest(
      file: Uint8List.fromList(bytes),
      purpose: purpose,
      filename: filename ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
    ));
  }

  /// Batch delete files
  Future<List<FileDeleteResponse>> deleteFiles(List<String> fileIds) async {
    final results = <FileDeleteResponse>[];

    for (final fileId in fileIds) {
      try {
        final result = await deleteFile(fileId);
        results.add(result);
      } catch (e) {
        // Continue with other files even if one fails
        results.add(FileDeleteResponse(
          id: fileId,
          object: 'file',
          deleted: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Get total storage used
  Future<int> getTotalStorageUsed({CancelToken? cancelToken}) async {
    final response = await listFiles(cancelToken: cancelToken);
    return response.data
        .map((file) => file.sizeBytes)
        .fold<int>(0, (sum, bytes) => sum + bytes);
  }

  /// Clean up old files (older than specified days)
  Future<List<FileDeleteResponse>> cleanupOldFiles(int olderThanDays,
      {CancelToken? cancelToken}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final response = await listFiles(cancelToken: cancelToken);

    final oldFiles = response.data.where((file) {
      return file.createdAt.isBefore(cutoffDate);
    }).toList();

    if (oldFiles.isEmpty) {
      return [];
    }

    return await deleteFiles(oldFiles.map((f) => f.id).toList());
  }
}
