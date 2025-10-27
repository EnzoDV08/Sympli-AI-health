import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

void logD(String msg, {String name = 'APP'}) {
  if (kDebugMode) dev.log(msg, name: name, level: 500);
}
void logI(String msg, {String name = 'APP'}) {
  if (kDebugMode) dev.log(msg, name: name, level: 800);
}
void logW(String msg, {String name = 'APP'}) {
  if (kDebugMode) dev.log(msg, name: name, level: 900);
}
void logE(String msg, Object? error, StackTrace? st, {String name = 'APP'}) {
  if (kDebugMode) dev.log(msg, name: name, level: 1000, error: error, stackTrace: st);
}
