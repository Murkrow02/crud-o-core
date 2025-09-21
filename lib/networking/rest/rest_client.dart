import 'dart:convert';
import 'dart:typed_data';
import 'package:crud_o_core/bus/events/unauthorized_bus_event.dart';
import 'package:crud_o_core/configuration/crudo_configuration.dart';
import 'package:crud_o_core/core/utility/toaster.dart';
import 'package:crud_o_core/exceptions/api_validation_exception.dart';
import 'package:crud_o_core/exceptions/rest_exception.dart';
import 'package:crud_o_core/exceptions/unauthorized_exception.dart';
import 'package:crud_o_core/networking/rest/requests/rest_request.dart';
import 'package:crud_o_core/configuration/rest_client_configuration.dart';
import 'package:crud_o_core/bus/crudo_bus.dart';
import 'package:http/http.dart' as http;

class RestClient {

  // Logger instance
  final logger = CrudoConfiguration.logger();

  // Rest client configuration
  RestClientConfiguration _configuration = CrudoConfiguration.rest();

  RestClient({
    RestClientConfiguration? configuration,
  }) {
    if (configuration != null) {
      _configuration = configuration;
    }
  }

  // Function to perform a GET request
  Future<dynamic> get(String endpoint, {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    logger.d("GET: $uri");
    final response = await http
        .get(
          uri,
          headers: await _configuration.getHeaders!(),
        )
        .timeout(Duration(seconds: _configuration.timeoutSeconds));
    return _handleResponseAndDecodeBody(response);
  }

  // Function to perform a PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data,
      {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    var validatedData = _validateJson(data);
    logger.d("PUT: $uri");
    final response = await http
        .put(
          uri,
          body: jsonEncode(validatedData),
          headers: await _configuration.getHeaders!(),
        )
        .timeout(Duration(seconds: _configuration.timeoutSeconds));
    return _handleResponseAndDecodeBody(response);
  }

  // Function to perform a POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data,
      {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    logger.d("POST: $uri");
    var validatedData = _validateJson(data);
    final response = await http
        .post(
          uri,
          body: jsonEncode(validatedData),
          headers: await _configuration.getHeaders!(),
        )
        .timeout(Duration(seconds: _configuration.timeoutSeconds));
    return _handleResponseAndDecodeBody(response);
  }

  // Function to perform a DELETE request
  Future<dynamic> delete(String endpoint, {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    logger.d("DELETE: $uri");
    final response = await http
        .delete(
          uri,
          headers: await _configuration.getHeaders!(),
        )
        .timeout(Duration(seconds: _configuration.timeoutSeconds));
    return _handleResponseAndDecodeBody(response);
  }

  // Function to perform a PATCH request
  Future<dynamic> patch(String endpoint, Map<String, dynamic> data,
      {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    var validatedData = _validateJson(data);
    logger.d("PATCH: $uri");
    final response = await http
        .patch(
          uri,
          body: jsonEncode(validatedData),
          headers: await _configuration.getHeaders!(),
        )
        .timeout(Duration(seconds: _configuration.timeoutSeconds));
    return _handleResponseAndDecodeBody(response);
  }

  Future<Uint8List?> downloadFileBytes(String endpoint, {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    return downloadFileBytesFromUri(uri, request: request);
  }

  Future<Uint8List?> downloadFileBytesFromUri(Uri uri, {RestRequest? request}) async {
    logger.d("Downloading file: $uri");
    final response = await http.get(
      uri,
      headers: await _configuration.getHeaders!(),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw RestException("Failed to download file", response.statusCode);
    }
  }

  Future<http.Response> uploadFile(
      String endpoint, Uint8List data, String fieldName, String fileName,
      {RestRequest? request}) async {
    Uri uri = _buildUri(endpoint, request);
    logger.d("Uploading file: $uri");

    // Create a multipart request
    final multipartRequest = http.MultipartRequest('POST', uri);

    // Add headers except Content-Type (automatically handled by MultipartRequest)
    final headers = await _configuration.getHeaders!();
    headers.remove(
        'Content-Type'); // Remove Content-Type if set in configuration headers
    multipartRequest.headers.addAll(headers);

    // Add the file as form data with the specified field name
    multipartRequest.files.add(http.MultipartFile.fromBytes(
      fieldName, // This is the field name, e.g., "image"
      data,
      filename: fileName,
      //contentType: MediaType('image', 'png'), // Specify MIME type
    ));

    // Send the request
    final streamedResponse = await multipartRequest.send();

    // Convert the streamed response to a standard HTTP response
    final response = await http.Response.fromStream(streamedResponse);

    // Check for success status and handle response
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response;
    } else {
      throw Exception('Failed to upload file: ${response.body}');
    }
  }

  // Generic response handler, returns response as dynamic after decoding and handling errors
  Future<dynamic> _handleResponseAndDecodeBody(http.Response response) async {
    // Internal server error
    if (response.statusCode == 500) {
      logger.e("Request: ${response.request?.url} failed. \n ${response.body}");
      throw RestException(
          "Internal server error, please try again later", response.statusCode);
    }

    // Unauthorized
    if (response.statusCode == 401) {
      logger.e("Request: ${response.request?.url} failed. \n ${response.body}");
      crudoEventBus.fire(UnauthorizedBusEvent(response: response));
      throw UnauthorizedException("Unauthorized");
    }

    // Check if response is empty
    if (response.body.isEmpty) {
      return null;
    }

    // Decode response body
    dynamic decodedBody = json.decode(response.body);

    // Validation error, throw exception that will be handled in UI
    if (response.statusCode == 422) {
      Map<String, List<String>> errors = {};
      for (var key in decodedBody['errors'].keys) {
        errors[key] = decodedBody['errors'][key].cast<String>();
      }
      throw ApiValidationException(errors);
    }

    // Check if need to show message in toast
    String? message = decodedBody['message'];

    // Error
    if (response.statusCode != 200 && response.statusCode != 201) {
      // Display error message
      if (message != null && message.isNotEmpty) {
        Toaster.error(message);
      }
      throw RestException(
          message != null ? "" : "An error occurred", response.statusCode);
    }

    // Display success message
    if (message != null && message.isNotEmpty) Toaster.success(message);

    // No data? Throw exception as response is not well formatted
    if (decodedBody['data'] == null) {
      throw RestException(
          "Response is not well formatted", response.statusCode);
    }

    return decodedBody;
  }

  Map<String, dynamic> _validateJson(Map<String, dynamic> json) {
    Map<String, dynamic> validatedJson = {};
    json.forEach((key, value) {
      if (value is DateTime) {
        validatedJson[key] = value.toIso8601String();
      } else {
        validatedJson[key] = value;
      }
    });
    return validatedJson;
  }

  // Build final uri with parameters
  Uri _buildUri(String endpoint, RestRequest? request) {
    String url = _configuration.baseUrl;
    return Uri.parse(
        '$url/$endpoint${request != null ? '?${request.toQueryString()}' : ''}');
  }
}
