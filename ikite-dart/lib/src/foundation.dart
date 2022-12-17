part of '../ikite.dart';
abstract class IKiteDebugOptions{
  bool get isDebug;
}
mixin _IKiteDebugOptionsImpl implements IKiteDebugOptions{
  @override
  bool isDebug = false;
}
