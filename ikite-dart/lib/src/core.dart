part of '../ikite.dart';

abstract class IKite with IKiteConverter, _IKiteDebugOptionsImpl {}

class _IKiteImpl extends IKite {
  _IKiteImpl();
}

typedef IKitePlugin = void Function(IKite kite);

extension IKitePluginEx on IKite {
  void install(IKitePlugin plugin) {
    plugin(this);
  }

  void installAll(List<IKitePlugin> plugins) {
    for (final plugin in plugins) {
      install(plugin);
    }
  }
}
