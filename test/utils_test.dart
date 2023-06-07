// Copyright © 2020 Birju Vachhani. All rights reserved.
// Use of this source code is governed by an Apache license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:spider/src/cli/models/spider_config.dart';
import 'package:spider/src/cli/process_terminator.dart';
import 'package:spider/src/cli/utils/utils.dart';
import 'package:spider/src/generation_utils.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  final MockProcessTerminator processTerminatorMock = MockProcessTerminator();
  const Map<String, dynamic> testConfig = {
    "generate_tests": false,
    "no_comments": true,
    "export": true,
    "use_part_of": true,
    "use_references_list": true,
    "package": "resources",
    "groups": [
      {
        "path": "assets/images",
        "class_name": "Assets",
        "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
      }
    ]
  };

  group('Utils tests', () {
    test('extension formatter test', () {
      expect('.png', formatExtension('png'));
      expect('.jpg', formatExtension('.jpg'));
    });

    test('process terminator singleton test', () {
      expect(ProcessTerminator.getInstance(),
          equals(ProcessTerminator.getInstance()));
      expect(
          identical(
              ProcessTerminator.getInstance(), ProcessTerminator.getInstance()),
          isTrue);
    });

    test('checkFlutterProject test', () async {
      addTearDown(() async {
        await File(p.join(Directory.current.path, 'pubspec.txt'))
            .rename('pubspec.yaml');
        reset(processTerminatorMock);
      });

      expect(isFlutterProject(), isTrue);

      await File(p.join(Directory.current.path, 'pubspec.yaml'))
          .rename('pubspec.txt');

      expect(isFlutterProject(), isFalse);
    });

    test('getReference test', () async {
      expect(
          getReference(
            properties: 'static const',
            assetName: 'avatar',
            assetPath: 'assets/images/avatar.png',
          ),
          equals("static const String avatar = 'assets/images/avatar.png';"));
    });

    test('getTestCase test', () async {
      expect(getTestCase('Images', 'avatar'),
          equals("expect(File(Images.avatar).existsSync(), isTrue);"));
    });

    test('writeToFile test', () async {
      writeToFile(name: 'test.txt', path: 'resources', content: 'Hello');
      final file = File('lib/resources/test.txt');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), equals('Hello'));

      addTearDown(() {
        file.deleteSync();
        Directory('lib/resources').deleteSync();
      });
    });

    test('getExportContent test', () async {
      expect(getExportContent(fileNames: ['test.dart'], noComments: true),
          equals("export 'test.dart';"));

      expect(getExportContent(fileNames: ['test.dart'], noComments: false),
          contains('Generated by spider'));

      expect(
          getExportContent(
              fileNames: ['test.dart'], noComments: true, usePartOf: true),
          equals("part 'test.dart';"));
    });
  });

  group('parse config tests', () {
    setUp(() {
      ProcessTerminator.setMock(processTerminatorMock);
      deleteConfigFiles();
    });

    test('no config file test', () async {
      final Result<SpiderConfiguration> configs = retrieveConfigs();
      expect(configs.isSuccess, isFalse);
      expect(configs.error, ConsoleMessages.configNotFoundDetailed);
    });

    test('empty yaml config file test', () async {
      File('spider.yaml').createSync();

      final configs = retrieveConfigs();
      expect(configs.isError, isTrue);
      expect(configs.error, ConsoleMessages.parseError);
    });

    test('empty yml config file test', () async {
      File('spider.yml').createSync();

      final configs = retrieveConfigs();
      expect(configs.isError, isTrue);
      expect(configs.error, ConsoleMessages.parseError);
    });

    test('empty json config file test', () async {
      File('spider.json').writeAsStringSync('{}');

      final configs = retrieveConfigs();
      expect(configs.isError, isTrue);
      expect(configs.error, ConsoleMessages.invalidConfigFile);
    });

    test('invalid json config file test', () async {
      File('spider.json').createSync();

      final configs = retrieveConfigs();
      expect(configs.isError, isTrue);
      expect(configs.error, ConsoleMessages.parseError);
    });

    test('valid config file test', () async {
      createTestConfigs(testConfig);
      createTestAssets();

      Result<SpiderConfiguration> result = retrieveConfigs();
      expect(result.isSuccess, isTrue,
          reason: 'valid config file should not return error but it did.');

      SpiderConfiguration config = result.data;

      expect(config.groups, isNotEmpty);
      expect(config.groups.length, testConfig['groups'].length);
      expect(config.globals.generateTests, testConfig['generate_tests']);
      expect(config.globals.noComments, testConfig['no_comments']);
      expect(config.globals.export, testConfig['export']);
      expect(config.globals.usePartOf, testConfig['use_part_of']);
      expect(config.globals.package, testConfig['package']);

      createTestConfigs(testConfig.copyWith({'generate_tests': true}));

      result = retrieveConfigs();
      expect(result.isSuccess, isTrue,
          reason: 'valid config file should not return error but it did.');

      config = result.data;

      expect(config.globals.generateTests, isTrue);
      expect(config.globals.projectName, isNotNull);
      expect(config.globals.projectName, isNotEmpty);
      expect(config.globals.projectName, equals('spider'));
    });

    tearDown(() {
      deleteConfigFiles();
      reset(processTerminatorMock);
    });
  });

  group('validateConfigs tests', () {
    setUp(() {
      ProcessTerminator.setMock(processTerminatorMock);
    });

    test('nothing to generate test', () async {
      Result<bool> result = validateConfigs(testConfig.except('groups'));
      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.nothingToGenerate);

      result = validateConfigs(testConfig.except('groups')..['fonts'] = true);
      expect(result.isError, isFalse);

      result = validateConfigs(testConfig.except('groups'), allowEmpty: true);
      expect(result.isError, isFalse);
    });

    test('fonts config tests', () async {
      final baseConfig = testConfig.except('groups');
      Result<bool> result = validateConfigs(baseConfig..['fonts'] = true);

      expect(result.isSuccess, isTrue);

      result = validateConfigs(baseConfig..['fonts'] = false);
      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.nothingToGenerate);

      result = validateConfigs(baseConfig..['fonts'] = 123);
      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.invalidFontsConfig);

      result = validateConfigs(baseConfig..['fonts'] = <String, dynamic>{},
          fontsOnly: true);
      expect(result.isSuccess, isTrue);
    });

    test('config with no groups test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': true, // invalid group type.
      }));
      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.invalidGroupsType);
    });

    test('config group with null data test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "path": null, // null data
            "class_name": "Assets",
            "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
          }
        ],
      }));

      expect(result.isError, isTrue);
      expect(result.error, sprintf(ConsoleMessages.nullValueError, ['path']));
    });

    /// TODO(sanlvoty): refactor tests below, rewrite description.
    test('config group with no path test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "Assets",
            "sub_groups": [
              {
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));
      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.noPathInGroupError);
    });

    test('config group path with wildcard test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "Assets",
            "sub_groups": [
              {
                "path": "assets/*",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));
      expect(result.isError, isTrue);
      expect(result.error,
          sprintf(ConsoleMessages.noWildcardInPathError, ['assets/*']));
    });

    test('config group with non-existent path test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "Assets",
            "sub_groups": [
              {
                "path": "assets/fonts",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));
      expect(result.isError, isTrue);
      expect(result.error,
          sprintf(ConsoleMessages.pathNotExistsError, ['assets/fonts']));
    });

    test('config group path with invalid directory test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "Assets",
            "sub_groups": [
              {
                "path": "assets/images/test1.png",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));
      createTestAssets();

      expect(result.isError, isTrue);
      expect(
          result.error,
          sprintf(
              ConsoleMessages.pathNotExistsError, ['assets/images/test1.png']));
    });

    test('config group with class name null test', () async {
      createTestAssets();

      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "sub_groups": [
              {
                "path": "assets/images",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.noClassNameError);
    });

    test('config group with empty class name test', () async {
      createTestAssets();

      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "   ",
            "sub_groups": [
              {
                "path": "assets/images",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.emptyClassNameError);
    });

    test('config group with invalid class name test', () async {
      createTestAssets();

      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "My Assets",
            "sub_groups": [
              {
                "path": "assets/images",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.classNameContainsSpacesError);
    });

    test('config group with invalid paths data test', () async {
      final result = validateConfigs(testConfig.copyWith({
        'groups': [
          {
            "class_name": "Assets",
            "sub_groups": [
              {
                "paths": "assets/images",
                "types": ["jpg", "jpeg", "png", "webp", "gif", "bmp", "wbmp"]
              }
            ]
          }
        ],
      }));
      createTestAssets();

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.configValidationFailed);
    });

    test('default fonts config validation', () async {
      var result = validateConfigs(
        testConfig.copyWith({'fonts': true}),
        fontsOnly: true,
      );

      expect(result.isSuccess, isTrue);

      result = validateConfigs(
        testConfig.copyWith({'fonts': false}),
        fontsOnly: true,
      );

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.nothingToGenerate);
    });

    test('fonts config validation', () async {
      final result = validateConfigs(
        testConfig.copyWith({'fonts': 2}),
        fontsOnly: true,
      );

      expect(result.isError, isTrue);
      expect(result.error, ConsoleMessages.invalidFontsConfig);
    });

    tearDown(() {
      reset(processTerminatorMock);
      deleteConfigFiles();
      deleteTestAssets();
    });
  });
}
