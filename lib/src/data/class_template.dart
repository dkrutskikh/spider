// Copyright © 2020 Birju Vachhani. All rights reserved.
// Use of this source code is governed by an Apache license that can be
// found in the LICENSE file.

/// A template for generating file author line.
String get timeStampComment => '// Generated by spider on [TIME]\n\n';

/// A template for generating asset references class files.
String get classTemplate => '''class [CLASS_NAME] {
  const [CLASS_NAME]._();
  
  [REFERENCES]
  
  [LIST_OF_ALL_REFERENCES]
}''';

/// A template for generating reference variable declaration/signature.
String get referenceTemplate =>
    "[PROPERTIES] String [ASSET_NAME] = '[ASSET_PATH]';";

/// A template for generating list of all references variable.
String get referencesTemplate =>
    "[PROPERTIES] List<String> values = [LIST_OF_ALL_REFERENCES];";
