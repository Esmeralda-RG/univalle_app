import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:univalle_app/config/constants/sira_constants.dart';
import 'package:univalle_app/core/errors/handle_sira_errors.dart';
import 'package:univalle_app/core/errors/sira_exception.dart';
import 'package:univalle_app/config/providers/shared_preferences_provider.dart';
import 'package:univalle_app/features/auth/data/models/student_model.dart';
import 'package:univalle_app/features/auth/domain/datasources/auth_datasource.dart';
import 'package:univalle_app/core/domain/entities/student.dart';

class SiraAuthDatasource implements AuthDatasource {
  final _dio = Dio();
  final _cookieJar = CookieJar();
  late Student _student;
  final SharedStudentUtility _sharedStudentUtility;
  bool _isAuthenticated = false;
  SiraAuthDatasource(this._sharedStudentUtility) {
    _dio
      ..interceptors.add(CookieManager(_cookieJar))
      ..options.contentType = 'application/x-www-form-urlencoded'
      ..options.responseType = ResponseType.bytes;
  }

  Future<Response> _fetchBasicRating(String code) async {
    try {
      final response = await _dio
          .post(SiraConstants.baseUrl + SiraConstants.rantingPath, data: {
        'accion': 'Consultar Historial',
        'codigo_estudiante': code,
        'modulo': 'Academica',
        'x': '22',
        'y': '21'
      });
      final rantingDocument = parse(latin1.decode(response.data));
      final inputs = rantingDocument.querySelectorAll('form > input');
      final Map<String, String> data = {};
      for (final input in inputs) {
        data[input.attributes['name']!] = input.attributes['value']!;
      }
      data['TipoCarpeta'] = 'COMPLETA';
      data['DetalleCarpeta'] = 'COMPLETA';
      data['accion'] = 'Generar Carpeta';

      return await _dio.post(SiraConstants.baseUrl + SiraConstants.rantingPath,
          data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Student> _getStudent(String code, String password) async {
    try {
      final studentResponse = await _dio
          .post(SiraConstants.baseUrl + SiraConstants.studentPath, data: {
        'accion': 'desplegarFmInformacionDeContacto',
        'x': '31',
        'y': '24'
      });

      final rantingResponse = await _fetchBasicRating(code);
      if (studentResponse.statusCode != 200 ||
          rantingResponse.statusCode != 200) {
        throw SiraException('No se pudo obtener la información del estudiante');
      }
      final rantingDocument = parse(latin1.decode(rantingResponse.data));
      final studentDocument = parse(latin1.decode(studentResponse.data));

      final dataRanting = rantingDocument
              .querySelector('font')
              ?.text
              .trim()
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .map((e) => e.split(':')[1].trim())
              .toList() ??
          [];

      final accumulatedCredits = rantingDocument.querySelectorAll(
          'td[title="Acumulado: Número de Créditos Aprobados Acumulados"]');

      final studentModel = StudentModel(
          token: (await _cookieJar.loadForRequest(Uri.parse(SiraConstants.baseUrl)))
              .first
              .value,
          fristName: studentDocument
                  .querySelector('input[name="per_nombre"]')
                  ?.attributes['value'] ??
              '',
          lastName: studentDocument
                  .querySelector('input[name="per_apellido"]')
                  ?.attributes['value'] ??
              '',
          email: studentDocument
                  .querySelector('input[name="per_email_institucional"]')
                  ?.attributes['value'] ??
              '',
          documentId: studentDocument
                  .querySelector('input[name="per_doc_ide_numero"]')
                  ?.attributes['value'] ??
              '',
          password: password,
          average:
              double.tryParse(rantingDocument.querySelector('.error > font')?.text.trim() ?? '') ??
                  0,
          studentId: dataRanting[0].split(' -- ')[0],
          programId: dataRanting[2].split('-')[0],
          campus: dataRanting[2].split('-')[1],
          programName: dataRanting[2].split('-')[3],
          accumulatedCredits:
              int.tryParse(accumulatedCredits.isNotEmpty ? accumulatedCredits.last.text.trim() : '0') ?? 0,
          studentFines: await _getStudentFines(code, dataRanting[2].split('-')[0]));

      _sharedStudentUtility.saveStudentData(
          studentModel.token,
          '${studentModel.studentId.substring(2)}-${studentModel.programId}',
          studentModel.password);
      return studentModel.toEntity();
    } catch (e) {
      throw handleSiraError(e);
    }
  }

  Future<int> _getStudentFines(String code, String program) async {
    try {
      final response = await _dio
          .post(SiraConstants.baseUrl + SiraConstants.finesPath, data: {
        'est_codigo': code,
        'pra_codigo': program,
        'accion': 'ConsultarDeudasPublico',
        'boton': 'Buscar Deuda'
      });
      if (response.statusCode != 200) {
        throw SiraException('No se pudo obtener la información del estudiante');
      }
      final document = parse(latin1.decode(response.data));

      if (document.querySelector('.error')?.text.contains('NO TIENE DEUDAS') ??
          false) {
        return 0;
      }
      return (document
                  .querySelector('table[width=80%]')
                  ?.querySelectorAll('tr')
                  .length ??
              1) -
          1;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> login(String user, String password) async {
    try {
      if (user.isEmpty || password.isEmpty) {
        throw SiraException('Usuario y contraseña son requeridos');
      }

      final response = await _dio.post(SiraConstants.baseUrl,
          data: {
            'redirect': '',
            'usu_login_aut': user,
            'usu_password_aut': password,
            'boton': 'Ingresar al Sistema'
          },
          options: Options(
              followRedirects: false,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400));

      if (response.statusCode == 200) {
        final checkLogin = parse(latin1.decode(response.data));
        final errorMessage =
            checkLogin.querySelector('.resaltar')?.text.trim() ?? '';
        final error = errorMessage
            .replaceFirst(RegExp(r'^[A-Z]+\s*\d+\s*.*:\s'), '')
            .trim();
        throw SiraException(error);
      }
      _student = await _getStudent(user.split('-')[0], password);
    } catch (e) {
      throw handleSiraError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      _isAuthenticated = false;
      await _dio.get(SiraConstants.baseUrl + SiraConstants.logoutPath);
      await _cookieJar.deleteAll();
    } catch (e) {
      throw handleSiraError(e);
    }
  }

  @override
  Future<Student> getStudent() {
    return Future.value(_student);
  }

  @override
  Future<bool> isLogged() async {
    if (_isAuthenticated) {
      return Future.value(true);
    }
    final studentId = _sharedStudentUtility.getStudentId();
    final password = _sharedStudentUtility.getPassword();
    if (studentId != null && password != null) {
      await login(studentId, password);
      _isAuthenticated = true;
    }
    return Future.value(_isAuthenticated);
  }

  @override
  Future<void> resetPassword(String user) async {
    try {
      if (user.isEmpty) {
        throw SiraException('Usuario es requerido');
      }
      final response = await _dio.get(SiraConstants.resetPasswordPath,
          options: Options(
            responseType: ResponseType.plain,
          ));

      if (response.statusCode != 200) {
        throw SiraException('El servidor no responde');
      }
      final document = parse(response.data);
      final form = document.querySelector('form');
      if (form == null) {
        throw SiraException('El servicio no está disponible');
      }
      final token = form
          .querySelector('input[name="parametros[_csrf_token]"]')!
          .attributes['value'];

      final responseReset = await _dio.post(SiraConstants.resetPasswordPath,
          data: {'parametros[_csrf_token]': token, 'parametros[usuario]': user},
          options: Options(
            responseType: ResponseType.plain,
          ));

      if (responseReset.statusCode != 200) {
        throw SiraException('El servidor no responde');
      }

      final documentReset = parse(responseReset.data);
      if (documentReset.querySelector('.error') != null) {
        throw SiraException(documentReset.querySelector('.error')!.text);
      }
    } catch (e) {
      throw handleSiraError(e);
    }
  }
}
