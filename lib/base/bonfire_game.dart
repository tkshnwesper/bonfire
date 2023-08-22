// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:math';

import 'package:bonfire/base/base_game.dart';
import 'package:bonfire/base/bonfire_game_interface.dart';
import 'package:bonfire/bonfire.dart';
import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:bonfire/color_filter/color_filter_component.dart';
import 'package:bonfire/joystick/joystick_map_explorer.dart';
import 'package:bonfire/lighting/lighting_component.dart';
// ignore: implementation_imports
import 'package:flutter/widgets.dart';

/// Is a customGame where all magic of the Bonfire happen.
class BonfireGame extends BaseGame implements BonfireGameInterface {
  static const INTERVAL_UPDATE_ORDER = 500;

  /// Context used to access all Flutter power in your game.
  @override
  final BuildContext context;

  /// Represents the character controlled by the user in the game. Instances of this class has actions and movements ready to be used and configured.
  @override
  final Player? player;

  /// The way you can draw things like life bars, stamina and settings. In another words, anything that you may add to the interface to the game.
  @override
  final GameInterface? interface;

  /// Represents a map (or world) where the game occurs.
  @override
  final GameMap map;

  /// The player-controlling component.
  final JoystickController? _joystickController;

  /// Background of the game. This can be a color or custom component
  final GameBackground? background;

  /// Used to draw area collision in objects.
  @override
  final bool showCollisionArea;

  /// Color of the collision area when `showCollisionArea` is true
  @override
  final Color? collisionAreaColor;

  /// Used to configure lighting in the game
  final Color? lightingColorGame;

  @override
  final List<Force2D> globalForces;

  @override
  SceneBuilderStatus sceneBuilderStatus = SceneBuilderStatus();

  final List<GameComponent> _visibleComponents = List.empty(growable: true);
  late IntervalTick _intervalUpdateOder;
  late ColorFilterComponent _colorFilterComponent;
  late LightingComponent _lighting;

  ValueChanged<BonfireGame>? onReady;

  @override
  LightingInterface get lighting => _lighting;

  @override
  ColorFilterInterface get colorFilter => _colorFilterComponent;

  @override
  JoystickController? get joystick => _joystickController;

  @override
  Color backgroundColor() => _bgColor ?? super.backgroundColor();

  Color? _bgColor;

  bool _shouldUpdatePriority = false;

  @override
  late BonfireCamera bonfireCamera;

  late World world;

  /// variable that keeps the highest rendering priority per frame. This is used to determine the order in which to render the `interface`, `lighting` and `joystick`
  int _highestPriority = 1000000;

  /// Get of the _highestPriority
  @override
  int get highestPriority => _highestPriority;

  BonfireGame({
    required this.context,
    required this.map,
    JoystickController? joystickController,
    this.player,
    this.interface,
    List<GameComponent>? components,
    this.background,
    bool debugMode = false,
    this.showCollisionArea = false,
    this.collisionAreaColor,
    this.lightingColorGame,
    this.onReady,
    Color? backgroundColor,
    GameColorFilter? colorFilter,
    CameraConfig? cameraConfig,
    List<Force2D>? globalForces,
  })  : _joystickController = joystickController,
        globalForces = globalForces ?? [] {
    this.debugMode = debugMode;
    _bgColor = backgroundColor;
    _lighting = LightingComponent(
      color: lightingColorGame ?? const Color(0x00000000),
    );
    _colorFilterComponent = ColorFilterComponent(
      colorFilter ?? GameColorFilter(),
    );

    _intervalUpdateOder = IntervalTick(
      INTERVAL_UPDATE_ORDER,
      tick: updateOrderPriorityMicrotask,
    );

    world = World(
      children: [
        map,
        if (background != null) background!,
        if (player != null) player!,
        ...components ?? [],
      ],
    );

    bonfireCamera = BonfireCamera(
      config: cameraConfig ?? CameraConfig(),
      hudComponents: [
        _lighting,
        _colorFilterComponent,
        if (_joystickController != null) _joystickController!,
        if (interface != null) interface!,
      ],
      world: world,
    );

    _joystickController?.addObserver(
      player ?? JoystickMapExplorer(bonfireCamera),
    );
  }

  void updateOrderPriorityMicrotask() {
    if (_shouldUpdatePriority) {
      _shouldUpdatePriority = false;
      scheduleMicrotask(_updateOrderPriority);
    }
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    initializeCollisionDetection(
      mapDimensions: Rect.zero,
    );
    await super.add(world);
    await super.add(bonfireCamera);

    if (bonfireCamera.config.target != null) {
      bonfireCamera.follow(
        bonfireCamera.config.target!,
        snap: true,
      );
    } else if (player != null && bonfireCamera.config.startFollowPlayer) {
      bonfireCamera.moveToPlayer();
    }
  }

  void configCollision() {
    initializeCollisionDetection(
      mapDimensions: Rect.fromLTWH(
        0,
        0,
        map.size.x.ceilToDouble(),
        map.size.y.ceilToDouble(),
      ),
      minimumDistance: max(canvasSize.x, canvasSize.y) / 4,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _intervalUpdateOder.update(dt);
  }

  @override
  void onMount() {
    super.onMount();
    // ignore: invalid_use_of_internal_member
    setMounted();
    onReady?.call(this);
  }

  @override
  Iterable<T> visibles<T extends GameComponent>() {
    return _visibleComponents.whereType<T>();
  }

  @override
  Iterable<Enemy> livingEnemies({bool onlyVisible = false}) {
    return enemies(onlyVisible: onlyVisible)
        .where((element) => !element.isDead);
  }

  @override
  Iterable<Enemy> enemies({bool onlyVisible = false}) {
    return query<Enemy>(onlyVisible: onlyVisible);
  }

  @override
  Iterable<GameDecoration> decorations({bool onlyVisible = false}) {
    return query<GameDecoration>(onlyVisible: onlyVisible);
  }

  @override
  Iterable<Attackable> attackables({bool onlyVisible = false}) {
    return query<Attackable>(onlyVisible: onlyVisible);
  }

  @override
  Iterable<ShapeHitbox> collisions() {
    return collisionDetection.items;
  }

  @override
  Iterable<T> query<T extends Component>({bool onlyVisible = false}) {
    if (onlyVisible) {
      return _visibleComponents.whereType<T>();
    }
    return world.children.query<T>();
  }

  @override
  Vector2 worldToScreen(Vector2 position) {
    return bonfireCamera.worldToScreen(position);
  }

  @override
  Vector2 screenToWorld(Vector2 position) {
    return bonfireCamera.screenToWorld(position);
  }

  @override
  bool isVisibleInCamera(GameComponent c) {
    if (!hasLayout) return false;
    if (c.isRemoving) return false;
    return bonfireCamera.canSee(c);
  }

  /// Use this method to change default observer of the Joystick events.
  @override
  void addJoystickObserver(
    JoystickListener target, {
    bool cleanObservers = false,
    bool moveCameraToTarget = false,
  }) {
    if (cleanObservers) {
      _joystickController?.cleanObservers();
    }
    _joystickController?.addObserver(target);
    if (moveCameraToTarget && target is GameComponent) {
      bonfireCamera.follow(target as GameComponent);
    }
  }

  @override
  void startScene(List<SceneAction> actions, {void Function()? onComplete}) {
    if (!sceneBuilderStatus.isRunning) {
      add(SceneBuilderComponent(actions, onComplete: onComplete));
    }
  }

  @override
  void stopScene() {
    try {
      world.children
          .firstWhere((value) => value is SceneBuilderComponent)
          .removeFromParent();
    } catch (e) {
      /// Not found SceneBuilderComponent
    }
  }

  @override
  void onDetach() {
    world.children.query<GameComponent>().forEach(_detachComp);
    super.onDetach();
  }

  void _detachComp(GameComponent c) => c.onGameDetach();

  void addVisible(GameComponent obj) {
    _visibleComponents.add(obj);
  }

  void removeVisible(GameComponent obj) {
    _visibleComponents.remove(obj);
  }

  @override
  void enableGestures(bool enable) {
    enabledGestures = enable;
  }

  @override
  void enableKeyboard(bool enable) {
    enabledKeyboard = enable;
  }

  void requestUpdatePriority() {
    _shouldUpdatePriority = true;
  }

  @override
  FutureOr<void> add(Component component) {
    return world.add(component);
  }

  @override
  Future<void> addAll(Iterable<Component> components) {
    return world.addAll(components);
  }

  /// reorder components by priority
  void _updateOrderPriority() {
    // ignore: invalid_use_of_internal_member
    world.children.reorder();
    _highestPriority = world.children.last.priority;
  }

  @override
  List<RaycastResult<ShapeHitbox>> raycastAll(
    Vector2 origin, {
    required int numberOfRays,
    double startAngle = 0,
    double sweepAngle = tau,
    double? maxDistance,
    List<Ray2>? rays,
    List<ShapeHitbox>? ignoreHitboxes,
    List<RaycastResult<ShapeHitbox>>? out,
  }) {
    return collisionDetection.raycastAll(
      origin,
      numberOfRays: numberOfRays,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      maxDistance: maxDistance,
      rays: rays,
      ignoreHitboxes: ignoreHitboxes,
      out: out,
    );
  }

  @override
  RaycastResult<ShapeHitbox>? raycast(
    Ray2 ray, {
    double? maxDistance,
    List<ShapeHitbox>? ignoreHitboxes,
    RaycastResult<ShapeHitbox>? out,
  }) {
    return collisionDetection.raycast(
      ray,
      maxDistance: maxDistance,
      ignoreHitboxes: ignoreHitboxes,
      out: out,
    );
  }
}
