part of '../ikite.dart';

abstract class IKite with IKiteConverter {}

class _IKiteImpl extends IKite {
  _IKiteImpl();
}

typedef IKitePlugin = void Function(IKite kite);

extension IKitePluginEx on IKite {
  void addPlugin(IKitePlugin plugin) {
    plugin(this);
  }

  void addPlugins(List<IKitePlugin> plugins) {
    for (final plugin in plugins) {
      addPlugin(plugin);
    }
  }
}
